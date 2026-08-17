using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Reports;

var options = new DbContextOptionsBuilder<AfifeContext>()
    .UseSqlServer("Server=(localdb)\\MSSQLLocalDB;Database=YkbAfife;Trusted_Connection=True;TrustServerCertificate=True")
    .Options;

await using var context = new AfifeContext(options);
await context.Database.ExecuteSqlRawAsync("""
    IF COL_LENGTH(N'dbo.Users', N'IsJuryPresident') IS NULL
        ALTER TABLE dbo.Users ADD IsJuryPresident bit NOT NULL
            CONSTRAINT DF_Users_IsJuryPresident DEFAULT (0) WITH VALUES;
    """);
await context.Database.ExecuteSqlRawAsync("""
    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.Users')
          AND name = N'UX_Users_OnePublishedJuryPresident'
    )
        CREATE UNIQUE INDEX UX_Users_OnePublishedJuryPresident
            ON dbo.Users(IsJuryPresident)
            WHERE IsPublished = 1 AND IsJuryPresident = 1;
    """);
await context.Database.ExecuteSqlRawAsync("""
    IF OBJECT_ID(N'dbo.CK_Users_JuryPresident', N'C') IS NULL
        ALTER TABLE dbo.Users WITH CHECK ADD CONSTRAINT CK_Users_JuryPresident
            CHECK (IsJuryPresident = 0 OR (RoleCode = 2 AND IsActive = 1));
    """);
Console.WriteLine("IsJuryPresident schema objects are ready.");

var service = new PlayWatchReportService(context);
var report = await service.GetViewersPageAsync(new PlayViewerTableQuery
{
    PlayId = Guid.Parse("60000000-0000-0000-0000-000000000004")
});
Console.WriteLine($"Play: {report.PlayName}; viewers: {report.TotalCount}");
