using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Logging.Abstractions;
using YKBAfife.Data;
using YKBAfife.Data.Migrations;
using YKBAfife.Models.Entities;
using YKBAfife.Services.Audit;
using YKBAfife.Services.Authentication;
using AdminHash = YKBAfife.Business.Helpers.PasswordHashHelper;
using JuryHash = YkbAfife.Business.Helpers.PasswordHashHelper;

// Never load application settings/secrets or connect to an implicit database.
var connectionString = args.Length == 2 && args[0] == "--connection" ? args[1] : null;
if (string.IsNullOrWhiteSpace(connectionString))
    throw new ArgumentException("Use the disposable cross-panel authentication runner.");
var settings = new SqlConnectionStringBuilder(connectionString);
var allowedServer = Environment.GetEnvironmentVariable("AFIFE_TEST_SQL_SERVER") ?? @"(localdb)\MSSQLLocalDB";
if (!Regex.IsMatch(allowedServer, @"^\(localdb\)\\[A-Za-z0-9_-]+$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant) ||
    !Regex.IsMatch(settings.InitialCatalog, "^YkbAfifeCrossPanelTest_[a-f0-9]{32}$") ||
    !string.Equals(settings.DataSource, allowedServer, StringComparison.OrdinalIgnoreCase) ||
    !settings.IntegratedSecurity || settings.AttachDBFilename.Length != 0)
    throw new ArgumentException("Only the dedicated GUID-suffixed integrated-authentication LocalDB is allowed.");

var options = new DbContextOptionsBuilder<AfifeContext>()
    .UseSqlServer(connectionString, sql => sql.CommandTimeout(180))
    .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>().Options;
AfifeContext Open() => new(options);
await using (var context = Open()) await context.Database.MigrateAsync();

const string original = " Panel42<>&lt;onx=İıI i! ";
const string replacement = " Yeni43<>İıI i! ";
const string otherPassword = "Other44!";
var admin = Fixture("cross.admin", 1, AdminHash.HashPassword(original));
var modern = Fixture("cross.modern", 1, JuryHash.HashPassword(original));
var jury = Fixture("cross.jury", 2, AdminHash.HashPassword(original));
var inactiveAdmin = Fixture("cross.inactiveadmin", 1, JuryHash.HashPassword(original), active: false);
var inactiveJury = Fixture("cross.inactivejury", 2, JuryHash.HashPassword(original), active: false);
var hidden = Fixture("cross.hidden", 1, JuryHash.HashPassword(original), published: false);
var duplicateAdmin = Fixture("cross.shared", 1, AdminHash.HashPassword(original));
var duplicateJury = Fixture("cross.shared", 2, AdminHash.HashPassword(otherPassword));
var sameAdmin = Fixture("cross.same", 1, JuryHash.HashPassword(original));
var sameJury = Fixture("cross.same", 2, JuryHash.HashPassword(original));
await using (var context = Open())
{
    context.Users.AddRange(admin, modern, jury, inactiveAdmin, inactiveJury, hidden,
        duplicateAdmin, duplicateJury, sameAdmin, sameJury);
    await context.SaveChangesAsync();
    // IsActive/IsPublished have SQL defaults of true. EF's bool insertion
    // sentinel cannot represent explicit false here, so set fixture flags
    // after insertion exactly as an existing account's state is changed.
    var inactiveIds = new[] { inactiveAdmin.Id, inactiveJury.Id };
    await context.Users.Where(x => inactiveIds.Contains(x.Id))
        .ExecuteUpdateAsync(update => update.SetProperty(x => x.IsActive, false));
    await context.Users.Where(x => x.Id == hidden.Id)
        .ExecuteUpdateAsync(update => update.SetProperty(x => x.IsPublished, false));
}

var assertions = 0;
void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
    assertions++;
}

var initial = await Snapshot();
Check((await AdminLogin(admin.Username, original))?.UserId == admin.Id,
    "The real admin service authenticates the shared RoleCode=1 legacy row.");
Check(await Snapshot() == initial, "Admin login changes no user/hash field.");
var juryResult = await SuppliedJuryLogin(admin.Username, original);
Check(juryResult?.UserId == admin.Id, "The supplied jury flow authenticates the exact same RoleCode=1 row.");
var afterUpgrade = await Read(admin.Id);
Check(afterUpgrade.PasswordHash != admin.PasswordHash && afterUpgrade.PasswordHash.StartsWith("pbkdf2-sha256$600000$", StringComparison.Ordinal),
    "Successful jury login upgrades the legacy representation using the supplied helper.");
Check(afterUpgrade.UpdatedBy == admin.Id && afterUpgrade.UpdatedAt.HasValue,
    "Jury upgrade records its own user and timestamp.");
Check(AdminHash.VerifyPassword(original, afterUpgrade.PasswordHash) && JuryHash.VerifyPassword(original, afterUpgrade.PasswordHash),
    "Both production implementations verify the exact same password after upgrade.");
var upgraded = await Snapshot();
Check((await AdminLogin(admin.Username, original))?.UserId == admin.Id,
    "Real admin authentication still succeeds after the jury saved the modern hash.");
Check((await SuppliedJuryLogin(admin.Username, original))?.UserId == admin.Id,
    "Repeated jury authentication still selects the same shared user.");
Check(await Snapshot() == upgraded, "Neither repeated login rewrites the already-current hash.");

foreach (var row in new[] { admin, modern })
{
    Check((await AdminLogin(row.Username, original))?.UserId == row.Id,
        "Admin-created legacy and jury-created modern credentials work in the real admin service.");
    Check((await SuppliedJuryLogin(row.Username, original))?.UserId == row.Id,
        "The supplied jury query accepts the same eligible username/password.");
    Check(await AdminLogin(row.Username, original + "wrong") is null &&
          await SuppliedJuryLogin(row.Username, original + "wrong") is null,
        "Both flows reject the wrong password.");
    Check(await AdminLogin(row.Username, original.Trim()) is null &&
          await SuppliedJuryLogin(row.Username, original.Trim()) is null,
        "Neither flow silently trims the stored password value.");
}
Check(await Snapshot() == upgraded, "Successful current-format and failed login attempts change no user field.");

Check(await AdminLogin(jury.Username, original) is null, "RoleCode=2 cannot acquire an admin session.");
Check((await SuppliedJuryLogin(jury.Username, original))?.UserId == jury.Id, "RoleCode=2 is accepted by the supplied jury flow.");
Check(await AdminLogin(jury.Username, original) is null, "Jury rehash does not change RoleCode=2 admin eligibility.");
var eligibilitySnapshot = await Snapshot();
foreach (var row in new[] { inactiveAdmin, inactiveJury, hidden })
{
    var stored = await Read(row.Id);
    Check(!stored.IsActive || !stored.IsPublished, "The rejection fixture really is inactive or unpublished in SQL.");
    Check(await AdminLogin(row.Username, original) is null && await SuppliedJuryLogin(row.Username, original) is null,
        "Both flows reject inactive or unpublished users.");
}
Check(await AdminLogin("cross.absent", original) is null && await SuppliedJuryLogin("cross.absent", original) is null,
    "Both flows reject missing users.");
Check(await Snapshot() == eligibilitySnapshot, "Rejected eligibility attempts do not update credentials.");

await SetHash(admin.Id, AdminHash.HashPassword(replacement));
Check((await SuppliedJuryLogin(admin.Username, replacement))?.UserId == admin.Id,
    "An admin password replacement is accepted and upgraded by the jury flow.");
Check((await AdminLogin(admin.Username, replacement))?.UserId == admin.Id,
    "Admin accepts its replacement after the jury upgrades it.");
Check(await AdminLogin(admin.Username, original) is null && await SuppliedJuryLogin(admin.Username, original) is null,
    "The replaced password is rejected by both flows.");
await SetHash(admin.Id, JuryHash.HashPassword(original));
Check((await AdminLogin(admin.Username, original))?.UserId == admin.Id &&
      (await SuppliedJuryLogin(admin.Username, original))?.UserId == admin.Id,
    "A jury-format password replacement is accepted by both flows.");
Check(await AdminLogin(admin.Username, replacement) is null && await SuppliedJuryLogin(admin.Username, replacement) is null,
    "Both flows reject the password preceding the jury-format replacement.");

Check((await AdminLogin(" " + admin.Username, original))?.UserId == admin.Id,
    "The admin service trims accidental leading username whitespace.");
Check(await SuppliedJuryLogin(" " + admin.Username, original) is null,
    "Known discrepancy: the supplied jury query does not trim leading username whitespace.");

// These diagnostic assertions deliberately reproduce the supplied query's
// ambiguity. Passing them does not mean that the jury query is safe to ship.
await using (var context = Open())
{
    Check(await context.Users.CountAsync(x => x.IsPublished && x.IsActive &&
        (x.RoleCode == 1 || x.RoleCode == 2) && x.Username == duplicateAdmin.Username) == 2,
        "The real schema permits the same published username in the two roles.");
}
Check((await AdminLogin(duplicateAdmin.Username, original))?.UserId == duplicateAdmin.Id,
    "The role-filtered admin query unambiguously selects its own account.");
Guid? selectedA = null, selectedB = null;
var duplicateResultA = await SuppliedJuryLogin(duplicateAdmin.Username, original, id => selectedA = id);
var duplicateResultB = await SuppliedJuryLogin(duplicateAdmin.Username, otherPassword, id => selectedB = id);
// SQL does not promise the same unordered first row on separate executions.
// Observe each selection rather than baking that assumption into this check.
Check((selectedA == duplicateAdmin.Id || selectedA == duplicateJury.Id) &&
      (selectedB == duplicateAdmin.Id || selectedB == duplicateJury.Id) &&
      duplicateResultA?.UserId == (selectedA == duplicateAdmin.Id ? duplicateAdmin.Id : (Guid?)null) &&
      duplicateResultB?.UserId == (selectedB == duplicateJury.Id ? duplicateJury.Id : (Guid?)null),
    "Known defect: jury success depends on the unordered first role row, not on all matching credentials.");
Check(AdminHash.VerifyPassword(original, (await Read(duplicateAdmin.Id)).PasswordHash) &&
      AdminHash.VerifyPassword(otherPassword, (await Read(duplicateJury.Id)).PasswordHash),
    "The rejected alternate credential remains mathematically valid for its own account.");
await using (var context = Open())
{
    var matches = await context.Users.Where(x => x.IsPublished && x.IsActive &&
        (x.RoleCode == 1 || x.RoleCode == 2) && x.Username == sameAdmin.Username).ToListAsync();
    Check(matches.Count == 2 && matches.All(x => JuryHash.VerifyPassword(original, x.PasswordHash)),
        "Same username/password may identify two different permitted user rows.");
}
Check((await AdminLogin(sameAdmin.Username, original))?.UserId == sameAdmin.Id,
    "The admin role predicate still selects the correct RoleCode=1 identity.");
var ambiguous = await SuppliedJuryLogin(sameAdmin.Username, original);
Check(ambiguous.HasValue && (ambiguous.Value.UserId == sameAdmin.Id || ambiguous.Value.UserId == sameJury.Id),
    "Known ambiguity: the jury query returns the first identity without resolving the role.");

Console.WriteLine($"PASS: {assertions} cross-panel SQL authentication assertions using the real admin service and supplied jury authentication flow.");
Console.WriteLine($"OBSERVED: {2 - (duplicateResultA.HasValue ? 1 : 0) - (duplicateResultB.HasValue ? 1 : 0)} valid duplicate-role credentials rejected by the supplied first-row query.");
Console.WriteLine("CONFIRMED: eligible unique RoleCode=1 credentials work before/after legacy-to-SHA256 jury rehash and replacements in both directions.");
Console.WriteLine("KNOWN LIMITATIONS REPRODUCED: RoleCode=2 is intentionally not admin; leading username whitespace differs; cross-role duplicate usernames make the supplied jury FirstOrDefault query ambiguous.");

User Fixture(string username, int role, string hash, bool active = true, bool published = true) => new()
{
    Id = Guid.NewGuid(), FirstName = "Cross", LastName = "Panel", Username = username,
    Email = username + "." + role + "@example.invalid", PasswordHash = hash, RoleCode = role,
    IsActive = active, IsPublished = published, CreatedAt = new DateTime(2026, 10, 1)
};

async Task<AuthenticatedAdmin?> AdminLogin(string username, string password)
{
    await using var context = Open();
    var service = new AdminAuthenticationService(context,
        new UserActivityLogger(context, new HttpContextAccessor()), NullLogger<AdminAuthenticationService>.Instance);
    return await service.AuthenticateAsync(username, password);
}

async Task<(Guid UserId, string FullName)?> SuppliedJuryLogin(string userName, string password, Action<Guid>? observeSelectedId = null)
{
    // The exact database predicate and upgrade branch supplied by the user.
    // The separate jury application/controller/CAPTCHA are not hosted here.
    await using var context = Open();
    var user = await context.Users
        .Where(x => x.IsPublished && x.IsActive && (x.RoleCode == 1 || x.RoleCode == 2) && x.Username == userName)
        .FirstOrDefaultAsync();
    if (user is not null) observeSelectedId?.Invoke(user.Id); // Diagnostic only; does not affect selection/verification.
    if (user is null || string.IsNullOrEmpty(user.PasswordHash) || !JuryHash.VerifyPassword(password, user.PasswordHash))
        return null;
    if (JuryHash.NeedsRehash(user.PasswordHash))
    {
        user.PasswordHash = JuryHash.HashPassword(password);
        user.UpdatedAt = DateTime.Now;
        user.UpdatedBy = user.Id;
        await context.SaveChangesAsync();
    }
    return (user.Id, $"{user.FirstName} {user.LastName}".Trim());
}

async Task<User> Read(Guid id)
{
    await using var context = Open();
    return await context.Users.IgnoreQueryFilters().AsNoTracking().SingleAsync(x => x.Id == id);
}

async Task<string> Snapshot()
{
    await using var context = Open();
    return JsonSerializer.Serialize(await context.Users.IgnoreQueryFilters().AsNoTracking().OrderBy(x => x.Id)
        .Select(x => new { x.Id, x.Username, x.PasswordHash, x.RoleCode, x.IsActive, x.IsPublished, x.UpdatedAt, x.UpdatedBy })
        .ToListAsync());
}

async Task SetHash(Guid id, string hash)
{
    await using var context = Open();
    var user = await context.Users.SingleAsync(x => x.Id == id);
    user.PasswordHash = hash;
    await context.SaveChangesAsync();
}
