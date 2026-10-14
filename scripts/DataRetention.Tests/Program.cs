using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;
using Microsoft.Extensions.Logging.Abstractions;
using YKBAfife.Data;
using YKBAfife.Data.Migrations;

var connectionString = args.Length == 2 && args[0] == "--connection" ? args[1] : null;
if (string.IsNullOrWhiteSpace(connectionString)) throw new ArgumentException("Use the dedicated disposable database runner.");
var settings = new SqlConnectionStringBuilder(connectionString);
if (!Regex.IsMatch(settings.InitialCatalog, "^YkbAfifeDataRetentionTest_[a-f0-9]{32}$") ||
    !string.Equals(settings.DataSource, @"(localdb)\MSSQLLocalDB", StringComparison.OrdinalIgnoreCase) || !settings.IntegratedSecurity)
    throw new ArgumentException("Only a GUID-suffixed dedicated LocalDB retention database is allowed.");

await using var context = new AfifeContext(new DbContextOptionsBuilder<AfifeContext>()
    .UseSqlServer(connectionString).ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>().Options);
var generator = context.GetService<IMigrationsSqlGenerator>();
var assertions = 0;
void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
    assertions++;
}
async Task Execute(string sql)
{
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();
    await using var transaction = await connection.BeginTransactionAsync();
    await using var command = connection.CreateCommand();
    command.Transaction = (SqlTransaction)transaction;
    command.CommandText = sql;
    try
    {
        await command.ExecuteNonQueryAsync();
    }
    catch (SqlException exception) when (exception.Number is not (51020 or 51022 or 51024 or 51026))
    {
        Console.Error.WriteLine($"Retention fixture SQL failed: {sql}");
        throw;
    }
    await transaction.CommitAsync();
}
async Task<long> Number(string sql)
{
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();
    await using var command = connection.CreateCommand();
    command.CommandText = sql;
    return Convert.ToInt64(await command.ExecuteScalarAsync());
}
string Generated(MigrationOperation operation) => string.Join(Environment.NewLine, generator.Generate([operation]).Select(command => command.CommandText));
async Task Apply(MigrationOperation operation) => await Execute(Generated(operation));
bool Rejected(MigrationOperation operation)
{
    try { _ = Generated(operation); return false; }
    catch (InvalidOperationException) { return true; }
}

Check(generator is NoDataLossSqlServerMigrationsSqlGenerator, "The protected SQL generator is registered.");
Check(Rejected(new DeleteDataOperation { Table = "RetentionProbe", KeyColumns = ["Id"], KeyColumnTypes = ["int"], KeyValues = new object[,] { { 1 } } }), "DeleteData remains forbidden.");
Check(Rejected(new SqlOperation { Sql = "TRUNCATE TABLE dbo.RetentionProbe" }), "Unreviewed destructive SQL remains forbidden.");
AlterColumnOperation Alter(string oldType, string newType, bool oldNullable = true, bool newNullable = true) => new()
{
    Schema = "dbo", Table = "RetentionProbe", Name = "Original", ClrType = typeof(string),
    ColumnType = newType, IsNullable = newNullable,
    OldColumn = new AddColumnOperation { ClrType = typeof(string), ColumnType = oldType, IsNullable = oldNullable }
};
Check(!Rejected(Alter("nvarchar(30)", "nvarchar(60)")), "Same-type Unicode widening is allowed.");
Check(!Rejected(Alter("varchar(30)", "varchar(max)")), "Same-type max widening is allowed.");
Check(Rejected(Alter("nvarchar(max)", "nvarchar(60)")), "Unbounded string narrowing is blocked.");
Check(Rejected(Alter("nvarchar(60)", "nvarchar(30)")), "String narrowing is blocked.");
Check(Rejected(Alter("nvarchar(30)", "varchar(60)")), "Potential Unicode data loss is blocked.");
Check(Rejected(Alter("nvarchar(30)", "nvarchar(60)", true, false)), "Required alteration still needs a reviewed backfill.");

await Execute("CREATE TABLE dbo.RetentionProbe (Id int IDENTITY PRIMARY KEY, Original nvarchar(30) COLLATE Latin1_General_100_BIN2 NOT NULL DEFAULT N'untouched'); INSERT dbo.RetentionProbe (Original) VALUES (N'Türkçe original');");
await Apply(new AddColumnOperation { Schema = "dbo", Table = "RetentionProbe", Name = "FutureText", ClrType = typeof(string), ColumnType = "nvarchar(max)", IsNullable = true });
Check(await Number("SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.RetentionProbe') AND name=N'FutureText'") == 1, "Normal AddColumn retains standard EF behavior without an archive.");
await Apply(new DropColumnOperation { Schema = "dbo", Table = "RetentionProbe", Name = "Original" });
Check(await Number("SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.RetentionProbe') AND name=N'Original'") == 0, "Retired name is gone.");
Check(await Number("SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.RetentionProbe') AND name LIKE N'__Archived_Original[_]%' AND is_nullable=1 AND collation_name=N'Latin1_General_100_BIN2'") == 1, "Typed archive is nullable and keeps collation.");
try
{
    await Apply(new AddColumnOperation { Schema = "dbo", Table = "RetentionProbe", Name = "Original", ClrType = typeof(string), ColumnType = "nvarchar(60)", IsNullable = true });
    throw new InvalidOperationException("A differently typed archive must not be replaced silently.");
}
catch (SqlException exception) when (exception.Number == 51022) { assertions++; }
await Apply(new AddColumnOperation { Schema = "dbo", Table = "RetentionProbe", Name = "Original", ClrType = typeof(string), ColumnType = "nvarchar(30)", IsNullable = false, DefaultValue = "untouched" });
Check(await Number("SELECT COUNT(*) FROM dbo.RetentionProbe WHERE Original=N'Türkçe original'") == 1, "Rollback restores original values, not an invented default.");
Check(await Number("SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.RetentionProbe') AND name=N'Original' AND is_nullable=0") == 1, "Required shape is restored when all retained values exist.");
Check(await Number("SELECT COUNT(*) FROM sys.default_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.RetentionProbe')") == 1, "Requested default is restored.");

await Apply(new DropColumnOperation { Schema = "dbo", Table = "RetentionProbe", Name = "Original" });
await Execute("INSERT dbo.RetentionProbe DEFAULT VALUES;");
Check(await Number("SELECT COUNT(*) FROM dbo.RetentionProbe") == 2, "Nullable archives never block new inserts.");
try
{
    await Apply(new AddColumnOperation { Schema = "dbo", Table = "RetentionProbe", Name = "Original", ClrType = typeof(string), ColumnType = "nvarchar(30)", IsNullable = false, DefaultValue = "invented" });
    throw new InvalidOperationException("Unsafe required restoration must fail before overwriting retained values.");
}
catch (SqlException exception) when (exception.Number == 51024) { assertions++; }
await Apply(new AddColumnOperation { Schema = "dbo", Table = "RetentionProbe", Name = "Original", ClrType = typeof(string), ColumnType = "nvarchar(30)", IsNullable = true });
Check(await Number("SELECT COUNT(*) FROM dbo.RetentionProbe WHERE Original=N'Türkçe original'") == 1, "Nullable restoration keeps the original value.");
Check(await Number("SELECT COUNT(*) FROM dbo.RetentionProbe WHERE Original IS NULL") == 1, "Nullable restoration keeps new-row nulls.");

await Execute("ALTER TABLE dbo.RetentionProbe ADD Ordinary int NULL; CREATE INDEX IX_Retention_Ordinary ON dbo.RetentionProbe(Ordinary);");
try
{
    await Apply(new DropColumnOperation { Schema = "dbo", Table = "RetentionProbe", Name = "Ordinary" });
    throw new InvalidOperationException("Retirement with an index dependency must fail.");
}
catch (SqlException exception) when (exception.Number == 51020) { assertions++; }
Check(await Number("SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.RetentionProbe') AND name=N'Ordinary'") == 1, "A dependency failure leaves the source column intact.");

// Exercise the actual deploy-only explicit legacy list, without mapping old fields.
await Execute("CREATE TABLE dbo.Users (Id int IDENTITY PRIMARY KEY, Photo nvarchar(max) NOT NULL DEFAULT N'old'); INSERT dbo.Users(Photo) VALUES (N'data:image/png;base64,abc'); CREATE TABLE dbo.Announcements (Id int IDENTITY PRIMARY KEY, BackgroundImage varbinary(max) NULL, Image nvarchar(30) NULL); INSERT dbo.Announcements(BackgroundImage,Image) VALUES (0x010203,N'old.png'); CREATE TABLE dbo.PlayAwardCategories (Id int IDENTITY PRIMARY KEY, Photo nvarchar(30) NULL, IsOld bit NOT NULL); INSERT dbo.PlayAwardCategories(Photo,IsOld) VALUES(N'candidate.png',1);");
var runner = typeof(AfifeContext).Assembly.GetType("YKBAfife.Data.Migrations.LegacyColumnCleanupRunner")!;
var run = runner.GetMethod("RunAsync", BindingFlags.Public | BindingFlags.Static)!;
async Task RunCleanup()
{
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();
    await (Task)run.Invoke(null, [context, connection, NullLogger.Instance, CancellationToken.None])!;
}
await RunCleanup();
await RunCleanup();
Check(await Number("SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.Users') AND name=N'Photo'") == 0, "Explicit cleanup retires the requested obsolete name.");
Check(await Number("SELECT COUNT(*) FROM sys.columns WHERE object_id IN (OBJECT_ID(N'dbo.Users'),OBJECT_ID(N'dbo.Announcements'),OBJECT_ID(N'dbo.PlayAwardCategories')) AND name LIKE N'__Archived[_]%'") == 5, "Cleanup retains all five columns exactly once across replay.");
await Execute("INSERT dbo.Users DEFAULT VALUES; INSERT dbo.PlayAwardCategories DEFAULT VALUES;");
Check(await Number("SELECT COUNT(*) FROM dbo.Users") == 2, "Retired required legacy fields do not block later user inserts.");
await Apply(new AddColumnOperation { Schema = "dbo", Table = "Users", Name = "Photo", ClrType = typeof(string), ColumnType = "nvarchar(max)", IsNullable = true });
await Apply(new AddColumnOperation { Schema = "dbo", Table = "Announcements", Name = "BackgroundImage", ClrType = typeof(byte[]), ColumnType = "varbinary(max)", IsNullable = true });
await Apply(new AddColumnOperation { Schema = "dbo", Table = "PlayAwardCategories", Name = "IsOld", ClrType = typeof(bool), ColumnType = "bit", IsNullable = true });
Check(await Number("SELECT COUNT(*) FROM dbo.Users WHERE Photo=N'data:image/png;base64,abc'") == 1, "Cleanup retains populated legacy text/base64 data.");
Check(await Number("SELECT COUNT(*) FROM dbo.Announcements WHERE BackgroundImage=0x010203") == 1, "Cleanup retains exact legacy binary image bytes.");
Check(await Number("SELECT COUNT(*) FROM dbo.PlayAwardCategories WHERE IsOld=1") == 1, "Cleanup retains legacy flag values on the same rows.");

await Execute("CREATE TABLE dbo.RetentionParent (Id int NOT NULL CONSTRAINT PK_RetentionParent PRIMARY KEY); INSERT dbo.RetentionParent VALUES (1); CREATE TABLE dbo.RetentionChild (Id int NOT NULL CONSTRAINT PK_RetentionChild PRIMARY KEY, ParentId int NOT NULL, Title nvarchar(20) NOT NULL DEFAULT N'new', CONSTRAINT FK_RetentionChild_Parent FOREIGN KEY(ParentId) REFERENCES dbo.RetentionParent(Id)); CREATE INDEX IX_RetentionChild_ParentId ON dbo.RetentionChild(ParentId); INSERT dbo.RetentionChild(Id,ParentId,Title) VALUES(10,1,N'retained row');");
await Apply(new DropTableOperation { Schema = "dbo", Name = "RetentionChild" });
Check(await Number("SELECT COUNT(*) FROM sys.tables WHERE object_id=OBJECT_ID(N'dbo.RetentionChild')") == 0, "Retired table name leaves the active schema.");
Check(await Number("SELECT COUNT(*) FROM sys.extended_properties WHERE class=1 AND minor_id=0 AND name=N'Afife:ArchivedTableSource' AND CONVERT(nvarchar(128),value)=N'RetentionChild'") == 1, "Retained table has explicit original-name metadata.");
var replacement = new CreateTableOperation { Schema = "dbo", Name = "RetentionChild" };
replacement.Columns.Add(new AddColumnOperation { Table = "RetentionChild", Name = "Id", ColumnType = "int", ClrType = typeof(int), IsNullable = false });
replacement.Columns.Add(new AddColumnOperation { Table = "RetentionChild", Name = "ParentId", ColumnType = "int", ClrType = typeof(int), IsNullable = false });
replacement.Columns.Add(new AddColumnOperation { Table = "RetentionChild", Name = "Title", ColumnType = "nvarchar(20)", ClrType = typeof(string), IsNullable = false, DefaultValue = "new" });
replacement.PrimaryKey = new AddPrimaryKeyOperation { Schema = "dbo", Table = "RetentionChild", Name = "PK_RetentionChild", Columns = ["Id"] };
replacement.ForeignKeys.Add(new AddForeignKeyOperation { Schema = "dbo", Table = "RetentionChild", Name = "FK_RetentionChild_Parent", Columns = ["ParentId"], PrincipalSchema = "dbo", PrincipalTable = "RetentionParent", PrincipalColumns = ["Id"] });
try
{
    await Apply(replacement);
    throw new InvalidOperationException("A retained table must never be replaced with an empty table.");
}
catch (SqlException exception) when (exception.Number == 51026) { assertions++; }
Check(await Number("SELECT COUNT(*) FROM sys.tables WHERE object_id=OBJECT_ID(N'dbo.RetentionChild')") == 0, "Failed implicit table rollback did not create an empty replacement.");
Check(await Number("SELECT COUNT(*) FROM sys.key_constraints WHERE name=N'PK_RetentionChild'") == 1, "Retained table still owns its original primary key.");
Check(await Number("SELECT COUNT(*) FROM sys.foreign_keys WHERE name=N'FK_RetentionChild_Parent' AND delete_referential_action=0 AND update_referential_action=0") == 1, "Retained table keeps its no-action foreign key.");
Check(await Number("SELECT COUNT(*) FROM sys.indexes WHERE name=N'IX_RetentionChild_ParentId'") == 1, "Retained table keeps its original index.");
// A reviewed restoration renames the actual retained object, rather than rebuilding
// a second table or blindly skipping duplicate PK/FK/index names.
await Execute("DECLARE @retainedName sysname=(SELECT t.name FROM sys.tables t JOIN sys.extended_properties p ON p.class=1 AND p.major_id=t.object_id AND p.minor_id=0 WHERE p.name=N'Afife:ArchivedTableSource' AND CONVERT(nvarchar(128),p.value)=N'RetentionChild'); DECLARE @retainedObject nvarchar(517)=N'dbo.'+QUOTENAME(@retainedName); EXEC sys.sp_rename @retainedObject,N'RetentionChild',N'OBJECT';");
Check(await Number("SELECT COUNT(*) FROM dbo.RetentionChild WHERE Id=10 AND ParentId=1 AND Title=N'retained row'") == 1, "Explicit retained-table restoration keeps exact old rows.");
await Execute("INSERT dbo.RetentionChild(Id,ParentId) VALUES(11,1);");
Check(await Number("SELECT COUNT(*) FROM dbo.RetentionChild WHERE Id=11 AND Title=N'new'") == 1, "Restored table accepts new inserts with its original default.");
Check(await Number("SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.RetentionChild') AND name=N'Title' AND is_nullable=0 AND max_length=40") == 1, "Restored table keeps original required column type and length.");
Console.WriteLine($"PASS: {assertions} data-retention assertions using actual SQL generator and deploy cleanup.");
