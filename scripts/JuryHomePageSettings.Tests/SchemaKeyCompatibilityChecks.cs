using System.Reflection;
using System.Text;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using YKBAfife.Data;
using YKBAfife.Data.Migrations;

// Runs only inside the existing GUID-suffixed disposable LocalDB test runner.
// Company databases can have identical keys with SQL Server-generated names.
sealed class SchemaKeyCompatibilityChecks(string connectionString)
{
    private static readonly string[] LegacyTables =
    [
        "Announcements", "AwardCategories", "Configs", "Group", "Images",
        "JuryAssignedPlays", "JuryGameTicketFees", "JuryVotes", "PlayAwardCategories",
        "Plays", "PlayStatuses", "Roles", "Users"
    ];
    private static readonly MethodInfo Validate = typeof(AfifeContext).Assembly
        .GetType("YKBAfife.Data.Migrations.DatabaseSchemaValidator", throwOnError: true)!
        .GetMethod("ValidateAsync", BindingFlags.Static | BindingFlags.Public)!;
    private int assertions;

    private AfifeContext Context(IModel? model = null)
    {
        var options = new DbContextOptionsBuilder<AfifeContext>()
            .UseSqlServer(connectionString, sql => sql.CommandTimeout(180))
            .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>();
        if (model is not null) options.UseModel(model);
        return new AfifeContext(options.Options);
    }

    public async Task RunAsync()
    {
        await AssertValidAsync("Canonical migration-created keys pass schema validation.");
        var rows = await BusinessRowsAsync();
        var foreignKeys = await ForeignKeysAsync();
        var keyShapes = await KeyShapesAsync();
        foreach (var table in LegacyTables)
        {
            var name = "PK__" + table[..Math.Min(table.Length, 8)] + "__" + Guid.NewGuid().ToString("N")[..16].ToUpperInvariant();
            await ExecuteAsync("EXEC sys.sp_rename @object, @name, N'OBJECT';",
                ("@object", "dbo.PK_" + table), ("@name", name));
            Check(await NumberAsync("SELECT COUNT(*) FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(@table) AND type=N'PK' AND name=@name",
                ("@table", "dbo." + table), ("@name", name)) == 1,
                $"{table} retains its primary key under a SQL Server auto-style name.");
            Check(await NumberAsync("SELECT COUNT(*) FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(@table) AND name=@name",
                ("@table", "dbo." + table), ("@name", "PK_" + table)) == 0,
                $"The old strict PK_{table} name lookup fails, reproducing company startup errors.");
        }
        await ExecuteAsync("EXEC sys.sp_rename N'dbo.UQ_AwardCategories_CategoryCode', N'UQ_Legacy_CategoryCode', N'OBJECT';");
        Check(await NumberAsync("SELECT COUNT(*) FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.AwardCategories') AND type=N'UQ' AND name=N'UQ_Legacy_CategoryCode'") == 1,
            "An alternate key is also preserved under a legacy name.");
        Check(await KeyShapesAsync() == keyShapes, "Renamed primary/alternate keys preserve object IDs, indexed columns and backing-index shape.");
        Check(await ForeignKeysAsync() == foreignKeys, "Key renames preserve every foreign-key object, endpoint, trust and no-action rule.");
        Check(await BusinessRowsAsync() == rows, "Key renames preserve all existing business row values and IDs.");
        await AssertValidAsync("All thirteen renamed primary keys and renamed alternate key pass actual schema validation.");
        var renamedKeys = await KeyNamesAsync();
        await AssertHostedStartupAsync();
        Check(await KeyNamesAsync() == renamedKeys, "Hosted startup accepts legacy keys without silently renaming or recreating them.");
        Check(await KeyShapesAsync() == keyShapes && await ForeignKeysAsync() == foreignKeys,
            "Hosted startup preserves all key/foreign-key identities and definitions.");
        Check(await BusinessRowsAsync() == rows, "Hosted startup preserves business data and choices.");
        await TestMalformedPrimaryKeysAsync();
        await TestCompositeKeyOrderAndDisabledIndexAsync();
        await AssertValidAsync("Ordinary startup validation still succeeds after negative-test cleanup.");
        Check(await BusinessRowsAsync() == rows && await ForeignKeysAsync() == foreignKeys,
            "Negative validation probes never alter business data or foreign keys.");
        Console.WriteLine($"PASS: {assertions} schema-key compatibility assertions using actual validator and hosted startup.");
    }

    private async Task TestMalformedPrimaryKeysAsync()
    {
        var originalName = await TextAsync("SELECT name FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.Configs') AND type=N'PK'");
        try
        {
            await ExecuteAsync($"ALTER TABLE dbo.Configs DROP CONSTRAINT [{originalName}];");
            await AssertRejectedAsync("key dbo.Configs.PK_Configs", "A genuinely missing primary key is still rejected.");
            await ExecuteAsync("ALTER TABLE dbo.Configs ADD CONSTRAINT PK_Configs UNIQUE NONCLUSTERED (id);");
            await AssertRejectedAsync("key dbo.Configs.PK_Configs", "A unique constraint with the expected PK name is not accepted as a primary key.");
            await ExecuteAsync("ALTER TABLE dbo.Configs DROP CONSTRAINT PK_Configs; ALTER TABLE dbo.Configs ADD CONSTRAINT PK_Configs PRIMARY KEY CLUSTERED (id, IsPublished);");
            await AssertRejectedAsync("key dbo.Configs.PK_Configs", "A named primary key with the wrong column list is still rejected.");
        }
        finally
        {
            await ExecuteAsync("""
                DECLARE @name sysname = (SELECT name FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.Configs') AND type IN (N'PK',N'UQ') AND (type=N'PK' OR name=N'PK_Configs'));
                DECLARE @drop nvarchar(max)=N'ALTER TABLE dbo.Configs DROP CONSTRAINT ' + QUOTENAME(@name);
                IF @name IS NOT NULL EXEC sys.sp_executesql @drop;
                """);
            await ExecuteAsync($"ALTER TABLE dbo.Configs ADD CONSTRAINT [{originalName}] PRIMARY KEY CLUSTERED (id);");
        }
        await AssertValidAsync("A correctly restored legacy-named primary key is accepted.");
    }

    private async Task TestCompositeKeyOrderAndDisabledIndexAsync()
    {
        // No application entity or schema is changed: the archived-prefix probe is
        // test-only and deliberately excluded from active business audit tables.
        await ExecuteAsync("""
            CREATE TABLE dbo.__Archived_SchemaKeyProbe
            (
                Id int NOT NULL, Slot int NOT NULL, Token int NOT NULL,
                CONSTRAINT PK_Legacy_KeyProbe PRIMARY KEY NONCLUSTERED (Id, Slot),
                CONSTRAINT UQ_Legacy_KeyProbe UNIQUE NONCLUSTERED (Slot, Token)
            );
            """);
        await using var probeContext = new KeyProbeContext(new DbContextOptionsBuilder<KeyProbeContext>().UseSqlServer(connectionString).Options);
        var probeModel = probeContext.GetService<IDesignTimeModel>().Model;
        try
        {
            await AssertValidAsync("Renamed composite primary and alternate keys with correct ordered columns are accepted.", probeModel);
            await ExecuteAsync("ALTER TABLE dbo.__Archived_SchemaKeyProbe DROP CONSTRAINT PK_Legacy_KeyProbe; ALTER TABLE dbo.__Archived_SchemaKeyProbe ADD CONSTRAINT PK_Legacy_KeyProbe PRIMARY KEY NONCLUSTERED (Slot, Id);");
            await AssertRejectedAsync("key dbo.__Archived_SchemaKeyProbe.PK_SchemaKeyProbe", "A reordered composite primary key is rejected.", probeModel);
            await ExecuteAsync("ALTER TABLE dbo.__Archived_SchemaKeyProbe DROP CONSTRAINT PK_Legacy_KeyProbe; ALTER TABLE dbo.__Archived_SchemaKeyProbe ADD CONSTRAINT PK_Legacy_KeyProbe PRIMARY KEY NONCLUSTERED (Id, Slot); ALTER TABLE dbo.__Archived_SchemaKeyProbe DROP CONSTRAINT UQ_Legacy_KeyProbe; ALTER TABLE dbo.__Archived_SchemaKeyProbe ADD CONSTRAINT UQ_Legacy_KeyProbe UNIQUE NONCLUSTERED (Token, Slot);");
            await AssertRejectedAsync("key dbo.__Archived_SchemaKeyProbe.UQ_SchemaKeyProbe", "A reordered composite alternate key is rejected.", probeModel);
            await ExecuteAsync("ALTER TABLE dbo.__Archived_SchemaKeyProbe DROP CONSTRAINT UQ_Legacy_KeyProbe; CREATE UNIQUE INDEX UQ_Legacy_KeyProbe ON dbo.__Archived_SchemaKeyProbe (Slot, Token);");
            await AssertRejectedAsync("key dbo.__Archived_SchemaKeyProbe.UQ_SchemaKeyProbe", "An ordinary unique index does not replace a required alternate-key constraint.", probeModel);
            await ExecuteAsync("DROP INDEX UQ_Legacy_KeyProbe ON dbo.__Archived_SchemaKeyProbe; ALTER TABLE dbo.__Archived_SchemaKeyProbe ADD CONSTRAINT UQ_Legacy_KeyProbe UNIQUE NONCLUSTERED (Slot, Token); ALTER INDEX PK_Legacy_KeyProbe ON dbo.__Archived_SchemaKeyProbe DISABLE;");
            await AssertRejectedAsync("key dbo.__Archived_SchemaKeyProbe.PK_SchemaKeyProbe", "A disabled primary-key backing index is rejected.", probeModel);
            await ExecuteAsync("ALTER INDEX PK_Legacy_KeyProbe ON dbo.__Archived_SchemaKeyProbe REBUILD; ALTER INDEX UQ_Legacy_KeyProbe ON dbo.__Archived_SchemaKeyProbe DISABLE;");
            await AssertRejectedAsync("key dbo.__Archived_SchemaKeyProbe.UQ_SchemaKeyProbe", "A disabled alternate-key backing index is rejected.", probeModel);
            await ExecuteAsync("ALTER INDEX UQ_Legacy_KeyProbe ON dbo.__Archived_SchemaKeyProbe REBUILD;");
            await AssertValidAsync("Rebuilt composite-key backing indexes are accepted.", probeModel);
        }
        finally
        {
            // Only this empty, explicitly named disposable-DB test table is removed.
            await ExecuteAsync("DROP TABLE dbo.__Archived_SchemaKeyProbe;");
        }
    }

    private async Task AssertHostedStartupAsync()
    {
        var services = new ServiceCollection();
        services.AddDbContext<AfifeContext>(options => options.UseSqlServer(connectionString)
            .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>());
        await using var provider = services.BuildServiceProvider();
        var hosted = new DatabaseMigrationHostedService(provider.GetRequiredService<IServiceScopeFactory>(),
            new ConfigurationBuilder().Build(), NullLogger<DatabaseMigrationHostedService>.Instance);
        await hosted.StartAsync(CancellationToken.None);
        await hosted.StopAsync(CancellationToken.None);
        Check(true, "Real migration hosted service completes with legacy key names.");
    }

    private async Task ValidateAsync(IModel? model)
    {
        await using var context = Context(model);
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await (Task)Validate.Invoke(null, [context, connection, CancellationToken.None])!;
    }

    private async Task AssertValidAsync(string label, IModel? model = null)
    {
        await ValidateAsync(model);
        Check(true, label);
    }

    private async Task AssertRejectedAsync(string expected, string label, IModel? model = null)
    {
        var rejected = false;
        try { await ValidateAsync(model); }
        catch (InvalidOperationException error) when (error.Message.StartsWith("Database schema drift detected.", StringComparison.Ordinal))
        {
            rejected = error.Message.Contains(expected, StringComparison.Ordinal);
        }
        Check(rejected, label);
    }

    private async Task<string> BusinessRowsAsync()
    {
        var snapshot = new StringBuilder();
        foreach (var table in LegacyTables)
            snapshot.Append(table).Append(':').Append(await TextAsync($"SELECT * FROM dbo.[{table}] ORDER BY id FOR JSON PATH, INCLUDE_NULL_VALUES")).Append('|');
        return snapshot.ToString();
    }

    private Task<string> ForeignKeysAsync() => TextAsync("""
        SELECT object_id, name, parent_object_id, referenced_object_id, key_index_id,
            is_disabled, is_not_trusted, delete_referential_action, update_referential_action
        FROM sys.foreign_keys ORDER BY object_id FOR JSON PATH, INCLUDE_NULL_VALUES
        """);
    private Task<string> KeyShapesAsync() => TextAsync("""
        SELECT k.object_id, k.parent_object_id, k.type, k.unique_index_id, i.is_unique,
            i.is_disabled, i.type AS index_type, c.name AS column_name, ic.key_ordinal
        FROM sys.key_constraints k JOIN sys.indexes i ON i.object_id=k.parent_object_id AND i.index_id=k.unique_index_id
        JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
        JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
        WHERE ic.key_ordinal>0 ORDER BY k.object_id, ic.key_ordinal FOR JSON PATH, INCLUDE_NULL_VALUES
        """);
    private Task<string> KeyNamesAsync() => TextAsync("SELECT object_id, name FROM sys.key_constraints ORDER BY object_id FOR JSON PATH");

    private async Task ExecuteAsync(string sql, params (string Name, object Value)[] parameters)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        command.CommandTimeout = 180;
        foreach (var parameter in parameters) command.Parameters.AddWithValue(parameter.Name, parameter.Value);
        await command.ExecuteNonQueryAsync();
    }

    private async Task<long> NumberAsync(string sql, params (string Name, object Value)[] parameters) =>
        Convert.ToInt64(await ScalarAsync(sql, parameters));
    private async Task<object?> ScalarAsync(string sql, params (string Name, object Value)[] parameters)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        foreach (var parameter in parameters) command.Parameters.AddWithValue(parameter.Name, parameter.Value);
        return await command.ExecuteScalarAsync();
    }

    private async Task<string> TextAsync(string sql)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        await using var reader = await command.ExecuteReaderAsync();
        var result = new StringBuilder();
        while (await reader.ReadAsync()) if (!reader.IsDBNull(0)) result.Append(reader.GetString(0));
        return result.ToString();
    }

    private void Check(bool condition, string label)
    {
        if (!condition) throw new InvalidOperationException("FAIL: " + label);
        assertions++;
    }

    private sealed class KeyProbeContext(DbContextOptions<KeyProbeContext> options) : DbContext(options)
    {
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            var entity = modelBuilder.Entity<KeyProbe>();
            entity.ToTable("__Archived_SchemaKeyProbe", "dbo");
            entity.HasKey(row => new { row.Id, row.Slot }).HasName("PK_SchemaKeyProbe");
            entity.HasAlternateKey(row => new { row.Slot, row.Token }).HasName("UQ_SchemaKeyProbe");
        }
    }
    private sealed class KeyProbe
    {
        public int Id { get; set; }
        public int Slot { get; set; }
        public int Token { get; set; }
    }
}
