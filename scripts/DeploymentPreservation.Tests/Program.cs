using System.Security.Cryptography;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using YKBAfife.Business.Helpers;
using YKBAfife.Data;
using YKBAfife.Data.Migrations;
using YKBAfife.Services.Audit;
using YKBAfife.Services.Authentication;

// Deliberately never load appsettings, an application secret or an implicit DB.
var connectionString = args.Length == 2 && args[0] == "--connection" ? args[1] : null;
if (string.IsNullOrWhiteSpace(connectionString))
    throw new ArgumentException("Pass --connection for the disposable deployment-preservation runner.");
var settings = new SqlConnectionStringBuilder(connectionString);
var allowedServer = Environment.GetEnvironmentVariable("AFIFE_TEST_SQL_SERVER") ?? @"(localdb)\MSSQLLocalDB";
if (!Regex.IsMatch(allowedServer, @"^\(localdb\)\\[A-Za-z0-9_-]+$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant) ||
    !Regex.IsMatch(settings.InitialCatalog, "^YkbAfifeDeploymentPreservationTest_[a-f0-9]{32}$") ||
    !string.Equals(settings.DataSource, allowedServer, StringComparison.OrdinalIgnoreCase) ||
    !settings.IntegratedSecurity || settings.AttachDBFilename.Length != 0)
    throw new ArgumentException("Only the runner's GUID-suffixed integrated-authentication LocalDB is allowed.");

await new PreservationChecks(connectionString).RunAsync();

sealed class PreservationChecks(string connectionString)
{
    private const string PreviousMigration = "20261021151133_ScopedFormSynchronization_v_20261021181057";
    private const string KnownPassword = "Preservation-fixture-İstanbul-8!";
    private const string OpaqueHash = "$future$opaque:İstanbul/+/==  ";
    private readonly Guid adminLegacy = Guid.NewGuid();
    private readonly Guid adminModern = Guid.NewGuid();
    private readonly Guid adminInactive = Guid.NewGuid();
    private readonly Guid adminUnpublished = Guid.NewGuid();
    private readonly Guid adminOpaque = Guid.NewGuid();
    private readonly Guid jury = Guid.NewGuid();
    private readonly Guid inactiveJury = Guid.NewGuid();
    private readonly Guid retiredJury = Guid.NewGuid();
    private int assertions;

    public async Task RunAsync()
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ConnectionStrings:AfifeConnectionString"] = connectionString,
            ["DatabaseMigration:CommandTimeoutSeconds"] = "180"
        }).Build();
        var services = new ServiceCollection();
        services.AddSingleton<IConfiguration>(configuration);
        services.AddLogging(builder => builder.SetMinimumLevel(LogLevel.Warning));
        services.AddHttpContextAccessor();
        services.AddScoped<AdminAuditConnectionInterceptor>();
        services.AddDbContext<AfifeContext>((provider, options) => options
            .UseSqlServer(connectionString, sql => sql.CommandTimeout(180))
            .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>()
            .AddInterceptors(provider.GetRequiredService<AdminAuditConnectionInterceptor>()));
        services.AddScoped<IUserActivityLogger, UserActivityLogger>();
        services.AddScoped<IAdminAuthenticationService, AdminAuthenticationService>();
        await using var provider = services.BuildServiceProvider();
        await using (var scope = provider.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<AfifeContext>();
            Check(context.Database.GetMigrations().Contains(PreviousMigration), "Known previous production schema remains available.");
            await context.GetService<IMigrator>().MigrateAsync(PreviousMigration);
            Check((await context.Database.GetPendingMigrationsAsync()).Any(), "Fixture starts before the pending deployment migration.");
        }

        var legacyHash = LegacyHash(KnownPassword);
        var modernHash = ModernHash(KnownPassword);
        await SeedAsync(legacyHash, modernHash);
        // Exercise the optional legacy-index path on the throwaway DB as well.
        await ExecuteAsync("DROP INDEX IF EXISTS [IX_Form_SeasonId] ON dbo.Form;");
        var before = await SnapshotAsync();
        Check(new[] { "Users", "Form", "Plays", "PlayAwardCategories", "Images", "JuryVotes", "Rankings", "Seasons", "FormLifecycleStates", "AdditionalVotings", "AdditionalVotingJuries", "AdditionalVotingPlays", "AdditionalVotingUsages", "JuryAssignedPlays", "JuryGameTicketFees", "Blacklist", "Announcements", "Configs", "Group", "Manager", "Log", "JuryPasswordResetTokens" }
            .All(table => before.TryGetValue(table, out var rows) && rows.Rows.Count > 0), "Every main business table has a nonempty preservation fixture.");

        var hosted = new DatabaseMigrationHostedService(provider.GetRequiredService<IServiceScopeFactory>(),
            configuration, NullLogger<DatabaseMigrationHostedService>.Instance);
        for (var restart = 1; restart <= 3; restart++)
        {
            await hosted.StartAsync(default);
            var after = await SnapshotAsync();
            AssertPreserved(before, after, $"deployment/startup {restart}");
            await using var scope = provider.CreateAsyncScope();
            var context = scope.ServiceProvider.GetRequiredService<AfifeContext>();
            Check(!(await context.Database.GetPendingMigrationsAsync()).Any(), "Hosted startup applies pending migrations once and subsequent restarts have none.");
        }

        Check(PasswordHashHelper.VerifyPassword(KnownPassword, legacyHash), "Known legacy password verifies after deployment.");
        Check(PasswordHashHelper.VerifyPassword(KnownPassword, modernHash), "Known versioned PBKDF2-SHA256 password verifies after deployment.");
        Check(!PasswordHashHelper.VerifyPassword(KnownPassword, OpaqueHash), "Unknown opaque hash fails verification safely.");
        await using (var scope = provider.CreateAsyncScope())
        {
            var authentication = scope.ServiceProvider.GetRequiredService<IAdminAuthenticationService>();
            Check((await authentication.AuthenticateAsync("preserve.legacy", KnownPassword))?.UserId == adminLegacy,
                "Real admin login accepts the preserved legacy credential.");
            Check((await authentication.AuthenticateAsync("preserve.modern", KnownPassword))?.UserId == adminModern,
                "Real admin login accepts the preserved modern credential.");
            foreach (var rejected in new[] { "preserve.inactive", "preserve.unpublished", "preserve.opaque", "preserve.jury" })
                Check(await authentication.AuthenticateAsync(rejected, KnownPassword) is null,
                    "Inactive, unpublished, unsupported and jury credentials cannot become admin sessions.");
        }
        AssertPreserved(before, await SnapshotAsync(), "authentication and audit writes");
        var coveredRows = before.Where(item => !IsAppendOnly(item.Key)).Sum(item => item.Value.Rows.Count);
        var coveredCells = before.Where(item => !IsAppendOnly(item.Key)).Sum(item => item.Value.Rows.Count * item.Value.Columns.Count);
        Console.WriteLine($"PASS: {assertions} preservation assertions; {before.Count} tables, {coveredRows} existing business rows and {coveredCells} binary column values survive pending migration, three hosted startups and real authentication.");
        Console.WriteLine("Coverage includes active/inactive/unpublished users, legacy/modern/opaque hashes, custom labels/colors, config choices, image bytes, Form JSON, votes, ranking IDs/metrics and lifecycle history. Audit/history additions are counted separately; existing audit rows remain exact.");
    }

    private async Task SeedAsync(string legacyHash, string modernHash)
    {
        await ExecuteAsync("""
            DECLARE @Now datetime2(7) = '2090-07-01T12:34:56.1234567';
            DECLARE @Season uniqueidentifier = NEWID(), @Image uniqueidentifier = NEWID(),
                @Form uniqueidentifier = NEWID(), @InactiveForm uniqueidentifier = NEWID(),
                @HiddenForm uniqueidentifier = NEWID(), @Additional uniqueidentifier = NEWID();
            INSERT dbo.Images (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
            VALUES (@Image, N'preservation.png', N'image/png', @ImageBytes, @Now, @AdminLegacy, 1);
            INSERT dbo.[Group] (Id, Code, GroupName, CreatedAt, IsPublished)
            VALUES (NEWID(), 991, N'Özel Grup  ', @Now, 1);
            INSERT dbo.Users (Id, FirstName, LastName, Username, PasswordHash, Email, CreatedAt,
                IsPublished, RoleCode, GroupCode, PhotoImageId, IsActive, IsJuryPresident)
            SELECT fixture.Id, N'İstanbul', N'Korunan  ', fixture.Username, fixture.PasswordHash,
                fixture.Username + N'@example.invalid', @Now, fixture.Published, fixture.RoleCode, 991,
                @Image, fixture.Active, 0
            FROM (VALUES
                (@AdminLegacy, N'preserve.legacy', @LegacyHash, 1, 1, 1),
                (@AdminModern, N'preserve.modern', @ModernHash, 1, 1, 1),
                (@AdminInactive, N'preserve.inactive', @LegacyHash, 1, 1, 0),
                (@AdminUnpublished, N'preserve.unpublished', @LegacyHash, 0, 1, 0),
                (@AdminOpaque, N'preserve.opaque', @OpaqueHash, 1, 1, 1),
                (@Jury, N'preserve.jury', @LegacyHash, 1, 2, 1),
                (@InactiveJury, N'preserve.inactivejury', @OpaqueHash, 1, 2, 0),
                (@RetiredJury, N'preserve.retiredjury', @OpaqueHash, 0, 2, 0)
            ) fixture(Id, Username, PasswordHash, Published, RoleCode, Active);
            INSERT dbo.Seasons (Id, SeasonStartDate, SeasonEndDate, KunyeRegistrationStartDate,
                KunyeRegistrationEndDate, VotingStartDate, VotingEndDate, PlayCount, ActivePlayCount, VoteCount, IsPublished)
            VALUES (@Season, '20900101', '20910101', '20900101', '20900601', '20900601', '20910101', 0, 0, 0, 1);
            DECLARE @CandidateJson nvarchar(max) = N'[ {"Name":"Özel Oyuncu  ","Role":"Başrol","ImageUrl":"actor.png","Base64":"'
                + @Png + N'","Unmapped":"verbatim source İ"} ]';
            INSERT dbo.Form (Id, ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName, TheatreName,
                PremiereDate, Display, ApplicantName, ApplicantRole, Phone, Email, Director, ContactName,
                ContactPhone, LeadActress, YoungGenerationArtist, IsPublished, IsActive)
            SELECT f.Id, f.Number, @Now, @Now, f.Title, N'Özel Tiyatro  ', '20900102',
                N'[ {"opaque":"birebir İ / + ="} ]', N'Başvuran', N'İletişim', N'5550000000', N'preserve@example.invalid',
                N'Özel Yönetmen', N'İletişim Adı', N'5550000001', @CandidateJson, N'  legacy raw text İ  ', f.Published, f.Active
            FROM (VALUES (@Form, N'PR1001', N'Korunan Oyun', 1, 1),
                         (@InactiveForm, N'PR1002', N'Pasifleştirilen Oyun', 1, 1),
                         (@HiddenForm, N'PR1003', N'Yayınlanmayan Başvuru', 0, 0)) f(Id, Number, Title, Published, Active);
            DECLARE @Play uniqueidentifier = (SELECT Id FROM dbo.Plays WHERE SourceFormId = @Form);
            DECLARE @Candidate uniqueidentifier = (SELECT TOP (1) Id FROM dbo.PlayAwardCategories
                WHERE PlayId = @Play AND AwardCategoryCode = 1003 AND IsCurrent = 1);
            INSERT dbo.JuryVotes (Id, PlayAwardCategoryId, CreatedAt, CreatedBy, IsPublished, Score, JuryId, IsActive)
            VALUES (NEWID(), @Candidate, @Now, @AdminLegacy, 1, 7, @Jury, 1),
                   (NEWID(), @Candidate, @Now, @AdminLegacy, 0, 3, @Jury, 0);
            INSERT dbo.JuryAssignedPlays (Id, PlayId, CreatedAt, CreatedBy, IsPublished, JuryId)
            VALUES (NEWID(), @Play, @Now, @AdminLegacy, 1, @Jury),
                   (NEWID(), @Play, @Now, @AdminLegacy, 0, @InactiveJury);
            INSERT dbo.JuryGameTicketFees (Id, UserId, PlayId, TicketFee, CreatedAt, CreatedBy, IsPublished)
            VALUES (NEWID(), @Jury, @Play, 123.45, @Now, @AdminLegacy, 1),
                   (NEWID(), @InactiveJury, @Play, 42.10, @Now, @AdminLegacy, 0);
            INSERT dbo.Blacklist (Id, JuryId, PlayId, CreatedBy, CreatedOn, IsPublished)
            VALUES (NEWID(), @InactiveJury, @Play, @AdminLegacy, @Now, 1),
                   (NEWID(), @Jury, @Play, @AdminLegacy, @Now, 0);
            INSERT dbo.AdditionalVotings (Id, StartDate, EndDate, AppliesToAllJuries, AppliesToAllPlays,
                CreatedAt, CreatedBy, IsActive, IsPublished)
            VALUES (@Additional, '20900701', '20900710', 0, 0, @Now, @AdminLegacy, 1, 1),
                   (NEWID(), '20900702', '20900703', 1, 1, @Now, @AdminLegacy, 0, 0);
            INSERT dbo.AdditionalVotingJuries (Id, AdditionalVotingId, JuryId, CreatedAt, CreatedBy, IsActive, IsPublished)
            VALUES (NEWID(), @Additional, @Jury, @Now, @AdminLegacy, 1, 1);
            INSERT dbo.AdditionalVotingPlays (Id, AdditionalVotingId, PlayId, CreatedAt, CreatedBy, IsActive, IsPublished)
            VALUES (NEWID(), @Additional, @Play, @Now, @AdminLegacy, 1, 1);
            INSERT dbo.AdditionalVotingUsages (Id, AdditionalVotingId, JuryId, PlayId, UsageType, UsedAt,
                CreatedAt, CreatedBy, IsActive, IsPublished)
            VALUES (NEWID(), @Additional, @Jury, @Play, 0, @Now, @Now, @AdminLegacy, 1, 1);
            INSERT dbo.Announcements (Id, AnnouncementLocationId, Text, ButtonText, ButtonLink,
                BackgroundColor, CreatedAt, CreatedBy, IsPublished, ImageId)
            VALUES (NEWID(), 1, N'Özel Duyuru  ', N'İncele', N'/ozel?x=İ', N'#aBc123', @Now, @AdminLegacy, 1, @Image),
                   (NEWID(), 2, N'Eski Duyuru', NULL, NULL, N'#123abc', @Now, @AdminLegacy, 0, NULL);
            INSERT dbo.Manager (FullName, Email, Password, CreatedDate, IsPublished)
            VALUES (N'Eski Yönetici  ', N'manager@example.invalid', @LegacyHash, @Now, 1);
            INSERT dbo.Log (Title, Source, EventType, Message, CreatedDate, IsPublished)
            VALUES (N'Korunan Log', N'preservation', N'information', N'{"opaque":"İ"}', @Now, 1);
            INSERT dbo.JuryPasswordResetTokens (Id, UserId, TokenHash, CreatedAtUtc, ExpiresAtUtc)
            VALUES (NEWID(), @Jury, HASHBYTES('SHA2_256', N'fixture token'), @Now, DATEADD(MINUTE, 5, @Now));
            INSERT dbo.UsersLog (Id, UserId, ActorUserId, Username, EventType, IsSuccessful,
                OccurredAt, Application, Details, OldValue, NewValue, CorrelationId, IsPublished)
            VALUES (NEWID(), @AdminLegacy, @AdminLegacy, N'preserve.legacy', N'FixtureHistory', 1,
                @Now, N'AfifeAdmin', N'Korunan Geçmiş', N'İ  ', N'Ö  ', NEWID(), 1);
            INSERT dbo.JuryLogs (Id, CorrelationId, JuryId, PlayId, IsAdditionalVoting, OperationName,
                OperationType, AffectedVoteCount, OccurredAt, Application, Source, IsSuccessful, IsPublished)
            VALUES (NEWID(), NEWID(), @Jury, @Play, 0, N'Korunan Oy Geçmişi', N'FixtureHistory',
                1, @Now, N'AfifeJury', N'Fixture', 1, 1);
            UPDATE dbo.Form SET IsActive = 0 WHERE Id = @InactiveForm;
            /* Presentation choices deliberately differ from source defaults. */
            UPDATE dbo.Roles SET RoleName = N'Özel Rol ' + CONVERT(nvarchar(10), RoleCode) + N'  ';
            UPDATE dbo.PlayStatuses SET StatusName = N'Özel Durum ' + CONVERT(nvarchar(10), StatusCode), StatusColor = N'#aBcD12';
            UPDATE dbo.AwardCategories SET CategoryName = N'Özel Kategori ' + CONVERT(nvarchar(10), CategoryCode) + N'  ';
            UPDATE dbo.Configs SET ConfigValue = N'false' WHERE ConfigName IN (N'HomePageJuryTableEnabled', N'HomePageMostWatchedTableEnabled');
            INSERT dbo.Configs (id, ConfigName, ConfigValue, created_at, updated_at, IsPublished)
            VALUES (NEWID(), N'Preservation.Custom', N' Özel Değer  ', @Now, @Now, 0);
            """, ("@AdminLegacy", adminLegacy), ("@AdminModern", adminModern), ("@AdminInactive", adminInactive),
            ("@AdminUnpublished", adminUnpublished), ("@AdminOpaque", adminOpaque), ("@Jury", jury),
            ("@InactiveJury", inactiveJury), ("@RetiredJury", retiredJury), ("@LegacyHash", legacyHash),
            ("@ModernHash", modernHash), ("@OpaqueHash", OpaqueHash), ("@Png", Png), ("@ImageBytes", Convert.FromBase64String(Png)));
    }

    private static readonly string Png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";
    private static bool IsAppendOnly(string table) => table is "AdminLogs" or "JuryLogs" or "UsersLog" or "__EFMigrationsHistory";
    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        assertions++;
    }
    private static string Quote(string identifier) => "[" + identifier.Replace("]", "]]") + "]";

    private async Task<Dictionary<string, TableSnapshot>> SnapshotAsync()
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        var tables = new List<(string Name, List<string> Columns, List<string> Keys)>();
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = """
                SELECT t.name, c.name, COALESCE(ic.key_ordinal, 0)
                FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
                JOIN sys.columns c ON c.object_id = t.object_id
                LEFT JOIN sys.indexes i ON i.object_id = t.object_id AND i.is_primary_key = 1
                LEFT JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.column_id = c.column_id
                WHERE s.name = N'dbo' AND t.is_ms_shipped = 0 ORDER BY t.name, c.column_id;
                """;
            await using var reader = await command.ExecuteReaderAsync();
            var columns = new Dictionary<string, List<string>>();
            var keys = new Dictionary<string, List<(int Position, string Name)>>();
            while (await reader.ReadAsync())
            {
                var table = reader.GetString(0);
                if (!columns.ContainsKey(table)) { columns[table] = []; keys[table] = []; }
                columns[table].Add(reader.GetString(1));
                var ordinal = Convert.ToInt32(reader.GetValue(2));
                if (ordinal > 0) keys[table].Add((ordinal, reader.GetString(1)));
            }
            tables.AddRange(columns.Select(item => (item.Key, item.Value, keys[item.Key].OrderBy(key => key.Position).Select(key => key.Name).ToList())));
        }
        var snapshot = new Dictionary<string, TableSnapshot>();
        foreach (var table in tables)
        {
            Check(table.Keys.Count > 0, $"Snapshot table {table.Name} has a primary key.");
            await using var command = connection.CreateCommand();
            command.CommandText = "SELECT " + string.Join(",", table.Columns.Select(column => $"CONVERT(varbinary(max), {Quote(column)}) AS {Quote(column)}")) + " FROM dbo." + Quote(table.Name);
            command.CommandTimeout = 180;
            await using var reader = await command.ExecuteReaderAsync();
            var rows = new Dictionary<string, byte[]?[]>();
            while (await reader.ReadAsync())
            {
                var values = Enumerable.Range(0, table.Columns.Count).Select(index => reader.IsDBNull(index) ? null : (byte[])reader.GetValue(index)).ToArray();
                using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
                foreach (var key in table.Keys)
                {
                    var value = values[table.Columns.IndexOf(key)]!;
                    hash.AppendData(BitConverter.GetBytes(value.Length)); hash.AppendData(value);
                }
                rows.Add(Convert.ToHexString(hash.GetHashAndReset()), values);
            }
            snapshot.Add(table.Name, new TableSnapshot(table.Columns, rows));
        }
        return snapshot;
    }

    private void AssertPreserved(Dictionary<string, TableSnapshot> before, Dictionary<string, TableSnapshot> after, string phase)
    {
        foreach (var table in before)
        {
            Check(after.TryGetValue(table.Key, out var current), $"{phase}: table {table.Key} remains present.");
            if (!IsAppendOnly(table.Key))
                Check(current!.Rows.Count == table.Value.Rows.Count, $"{phase}: business row count remains exact for {table.Key}.");
            foreach (var row in table.Value.Rows)
            {
                Check(current!.Rows.TryGetValue(row.Key, out var values), $"{phase}: every preexisting {table.Key} row remains present.");
                for (var columnIndex = 0; columnIndex < table.Value.Columns.Count; columnIndex++)
                {
                    var column = table.Value.Columns[columnIndex];
                    var currentIndex = current.Columns.IndexOf(column);
                    Check(currentIndex >= 0, $"{phase}: {table.Key}.{column} remains present.");
                    var original = row.Value[columnIndex];
                    var actual = values![currentIndex];
                    Check(original is null ? actual is null : actual is not null && original.AsSpan().SequenceEqual(actual),
                        $"{phase}: {table.Key}.{column} changed binary value.");
                }
            }
            if (IsAppendOnly(table.Key))
                Console.WriteLine($"{phase}: {table.Key} additions = {current!.Rows.Count - table.Value.Rows.Count}; existing rows preserved.");
        }
    }

    private async Task ExecuteAsync(string sql, params (string Name, object Value)[] parameters)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = "SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF; " + sql;
        command.CommandTimeout = 180;
        foreach (var parameter in parameters) command.Parameters.AddWithValue(parameter.Name, parameter.Value);
        await command.ExecuteNonQueryAsync();
    }

    private static string LegacyHash(string password)
    {
        var salt = Enumerable.Range(1, 16).Select(value => (byte)value).ToArray();
        var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, 10_000, HashAlgorithmName.SHA1, 20);
        return Convert.ToBase64String(salt.Concat(hash).ToArray());
    }
    private static string ModernHash(string password)
    {
        var salt = Enumerable.Range(17, 16).Select(value => (byte)value).ToArray();
        var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, 100_000, HashAlgorithmName.SHA256, 32);
        return $"pbkdf2-sha256$100000${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
    }
    private sealed record TableSnapshot(List<string> Columns, Dictionary<string, byte[]?[]> Rows);
}
