using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Primitives;
using YKBAfife.Business.Helpers;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Security;
using JuryPasswordHashHelper = YkbAfife.Business.Helpers.PasswordHashHelper;

var assertions = 0;
void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
    assertions++;
}

// Fixed cross-machine vectors: salt bytes 00..0f; the password's Unicode,
// punctuation and surrounding spaces are deliberately part of its exact value.
const string exactPassword = " Zafer123< Türkçe Iıİi &lt; onx= ! ";
const string legacyVector = "AAECAwQFBgcICQoLDA0OD+HxdfZXku+/EBWFYoLK88Xl+Yo2";
const string modernVector = "pbkdf2-sha256$600000$AAECAwQFBgcICQoLDA0ODw==$4wyHsEuxlzAjHFcRmzR2ZXB/mSuyPiXWA10VkoM4oU0=";
var previousCulture = CultureInfo.CurrentCulture;
var previousUiCulture = CultureInfo.CurrentUICulture;
try
{
    foreach (var culture in new[] { "tr-TR", "en-US" })
    {
        CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo(culture);
        CultureInfo.CurrentUICulture = CultureInfo.GetCultureInfo(culture);
        Check(PasswordHashHelper.VerifyPassword(exactPassword, legacyVector), $"Legacy vector works under {culture}.");
        Check(PasswordHashHelper.VerifyPassword(exactPassword, modernVector), $"Modern jury vector works under {culture}.");
        Check(!PasswordHashHelper.VerifyPassword(exactPassword.Trim(), legacyVector), "Password whitespace is not trimmed.");
        Check(!PasswordHashHelper.VerifyPassword(exactPassword + "wrong", modernVector), "Wrong modern password is rejected.");
        Check(JuryPasswordHashHelper.VerifyPassword(exactPassword, legacyVector), $"The supplied jury implementation reads the same legacy vector under {culture}.");
        Check(JuryPasswordHashHelper.VerifyPassword(exactPassword, modernVector), $"The supplied jury implementation reads the same modern vector under {culture}.");
        Check(JuryPasswordHashHelper.NeedsRehash(legacyVector), "The jury upgrades the admin's legacy format after a successful login.");
        Check(!JuryPasswordHashHelper.NeedsRehash(modernVector), "A current jury hash requires no repeated upgrade.");
        Check(!JuryPasswordHashHelper.VerifyPassword(exactPassword.Trim(), legacyVector), "The jury also preserves password whitespace.");
        Check(!JuryPasswordHashHelper.VerifyPassword(exactPassword + "wrong", modernVector), "The jury rejects the same wrong modern password.");
    }
}
finally
{
    CultureInfo.CurrentCulture = previousCulture;
    CultureInfo.CurrentUICulture = previousUiCulture;
}

var generated = PasswordHashHelper.HashPassword(exactPassword);
var generatedBytes = Convert.FromBase64String(generated);
Check(generatedBytes.Length == 36, "New hashes retain the deployed jury's legacy wire format.");
var oldJuryComputed = Rfc2898DeriveBytes.Pbkdf2(exactPassword, generatedBytes[..16], 10_000, HashAlgorithmName.SHA1, 20);
Check(CryptographicOperations.FixedTimeEquals(oldJuryComputed, generatedBytes[16..]), "An independent deployed legacy reader accepts new hashes.");
Check(PasswordHashHelper.VerifyPassword(exactPassword, generated), "Generated legacy hash verifies.");
Check(generated != PasswordHashHelper.HashPassword(exactPassword), "New hashes use random salts.");
Check(!PasswordHashHelper.VerifyPassword("wrong", generated), "Wrong legacy password is rejected.");
var composed = PasswordHashHelper.HashPassword("École123!");
Check(!PasswordHashHelper.VerifyPassword("E\u0301cole123!", composed), "Unicode normalization never changes credential bytes.");
var whitespace = PasswordHashHelper.HashPassword(" \t ");
Check(PasswordHashHelper.VerifyPassword(" \t ", whitespace), "Existing whitespace credentials are verified as exact opaque strings.");
Check(!PasswordHashHelper.VerifyPassword(string.Empty, generated), "Empty password is rejected.");
Check(!PasswordHashHelper.VerifyPassword(null!, generated), "Null password is rejected.");
Check(!PasswordHashHelper.VerifyPassword(exactPassword, null!), "Null hash is rejected.");

// Exercise the actual supplied jury helper, rather than only reproducing its
// PBKDF2 parameters in this runner. The admin and jury namespaces are distinct.
Check(JuryPasswordHashHelper.VerifyPassword(exactPassword, generated), "The supplied jury verifies a freshly admin-generated password hash.");
Check(JuryPasswordHashHelper.NeedsRehash(generated), "The jury recognizes a freshly admin-generated hash as eligible for its normal upgrade.");
var juryGenerated = JuryPasswordHashHelper.HashPassword(exactPassword);
var juryParts = juryGenerated.Split('$');
Check(juryParts.Length == 4 && juryParts[0] == "pbkdf2-sha256" && juryParts[1] == "600000", "The supplied jury emits its current algorithm and iteration count.");
Check(Convert.FromBase64String(juryParts[2]).Length == 16, "A supplied-jury hash contains the supported 16-byte salt.");
Check(Convert.FromBase64String(juryParts[3]).Length == 32, "A supplied-jury hash contains the supported 32-byte SHA256 hash.");
Check(PasswordHashHelper.VerifyPassword(exactPassword, juryGenerated), "The admin accepts a hash created by the actual jury helper.");
Check(JuryPasswordHashHelper.VerifyPassword(exactPassword, juryGenerated), "The jury verifies its generated hash.");
Check(!JuryPasswordHashHelper.NeedsRehash(juryGenerated), "A jury-generated hash does not require another upgrade.");
Check(juryGenerated != JuryPasswordHashHelper.HashPassword(exactPassword), "The supplied jury uses independent random salts.");

// This is the hash transition performed by AuthenticateUserAsync. The plain
// password remains unchanged and must keep working in the other application.
var upgradedHash = generated;
if (JuryPasswordHashHelper.VerifyPassword(exactPassword, upgradedHash) && JuryPasswordHashHelper.NeedsRehash(upgradedHash))
    upgradedHash = JuryPasswordHashHelper.HashPassword(exactPassword);
Check(upgradedHash != generated && upgradedHash.StartsWith("pbkdf2-sha256$", StringComparison.Ordinal), "A successful jury login upgrades the stored representation.");
Check(PasswordHashHelper.VerifyPassword(exactPassword, upgradedHash), "The original password still logs into admin after the jury upgrade.");
Check(JuryPasswordHashHelper.VerifyPassword(exactPassword, upgradedHash), "The original password still logs into jury after the upgrade.");
Check(!JuryPasswordHashHelper.NeedsRehash(upgradedHash), "A second jury login does not upgrade the current representation again.");
Check(!PasswordHashHelper.VerifyPassword(exactPassword.Trim(), upgradedHash), "The upgrade does not trim the password for admin.");
Check(!JuryPasswordHashHelper.VerifyPassword(exactPassword.Trim(), upgradedHash), "The upgrade does not trim the password for jury.");
Check(!PasswordHashHelper.VerifyPassword(exactPassword + "wrong", upgradedHash), "Admin rejects a wrong password after the jury upgrade.");
Check(!JuryPasswordHashHelper.VerifyPassword(exactPassword + "wrong", upgradedHash), "Jury rejects a wrong password after the upgrade.");
Check(JuryPasswordHashHelper.VerifyPassword(exactPassword, PasswordHashHelper.HashPassword(exactPassword)), "An admin password reset remains readable by the jury after previous modern upgrades.");

foreach (var crossProjectPassword in new[]
{
    "École123!", "E\u0301cole123!", " \t ", "Abcd123<>\"'&\\{}=+$;%!", "\0opaque", "İIıi🚀Abc123!"
})
{
    var adminHash = PasswordHashHelper.HashPassword(crossProjectPassword);
    var juryHash = JuryPasswordHashHelper.HashPassword(crossProjectPassword);
    Check(JuryPasswordHashHelper.VerifyPassword(crossProjectPassword, adminHash), "Jury preserves exact Unicode, punctuation and whitespace when reading admin hashes.");
    Check(JuryPasswordHashHelper.NeedsRehash(adminHash), "Every supported admin-generated hash is upgradeable by the supplied jury.");
    Check(PasswordHashHelper.VerifyPassword(crossProjectPassword, juryHash), "Admin preserves exact Unicode, punctuation and whitespace when reading jury hashes.");
    Check(JuryPasswordHashHelper.VerifyPassword(crossProjectPassword, juryHash), "Jury verifies its own exact Unicode, punctuation and whitespace credentials.");
    Check(!JuryPasswordHashHelper.NeedsRehash(juryHash), "Exact credentials do not cause repeated jury rehashes.");
    Check(!PasswordHashHelper.VerifyPassword(crossProjectPassword + "wrong", juryHash), "Admin rejects a changed password in a jury-created hash.");
    Check(!JuryPasswordHashHelper.VerifyPassword(crossProjectPassword + "wrong", juryHash), "Jury rejects a changed password in its current format.");
    Check(!JuryPasswordHashHelper.VerifyPassword(crossProjectPassword + "wrong", adminHash), "Jury rejects a changed password in the admin legacy format.");
}
var juryComposed = JuryPasswordHashHelper.HashPassword("École123!");
Check(!JuryPasswordHashHelper.VerifyPassword("E\u0301cole123!", composed), "Jury never normalizes Unicode when reading the admin format.");
Check(!PasswordHashHelper.VerifyPassword("E\u0301cole123!", juryComposed), "Admin never normalizes Unicode when reading the jury format.");
Check(!JuryPasswordHashHelper.VerifyPassword("E\u0301cole123!", juryComposed), "Jury never normalizes Unicode in its current format.");
Check(!JuryPasswordHashHelper.VerifyPassword(string.Empty, generated), "The supplied jury rejects an empty password.");
Check(!JuryPasswordHashHelper.VerifyPassword(null!, generated), "The supplied jury rejects a null password.");
Check(!JuryPasswordHashHelper.VerifyPassword(exactPassword, null!), "The supplied jury rejects a null stored hash.");

foreach (var invalidHash in new[]
{
    "", " ", "not-a-hash", "argon2id$opaque-existing-format", "pbkdf2-sha256$", "pbkdf2-sha256$600000$bad$bad",
    modernVector + "$extra", modernVector.Replace("$600000$", "$99999$"),
    modernVector.Replace("$600000$", "$1000001$"), modernVector.Replace("$600000$", "$2147483648$"),
    modernVector.Replace("$600000$", "$-600000$"), modernVector.Replace("$600000$", "$ 600000$"),
    modernVector.Replace("$AAECAwQFBgcICQoLDA0ODw==$", "$AA==$"),
    "pbkdf2-sha256$600000$AAECAwQFBgcICQoLDA0ODw==$AA==", Convert.ToBase64String(new byte[35])
})
{
    Check(!PasswordHashHelper.VerifyPassword(exactPassword, invalidHash), "Malformed, unsupported or unbounded hash is rejected without fallback.");
    Check(!JuryPasswordHashHelper.VerifyPassword(exactPassword, invalidHash), "The supplied jury rejects the same malformed, unsupported or unbounded hash.");
}

var services = new ServiceCollection();
services.AddLogging();
services.AddControllers();
await using var provider = services.BuildServiceProvider();
var metadataProvider = provider.GetRequiredService<IModelMetadataProvider>();
var filter = new UnsafeInputValidationFilter(metadataProvider);

async Task<bool> Accepted(object model, Dictionary<string, StringValues>? form = null,
    string argumentName = "model", string? query = null)
{
    var httpContext = new DefaultHttpContext { RequestServices = provider };
    if (query is not null) httpContext.Request.QueryString = new QueryString(query);
    if (form is not null)
    {
        httpContext.Request.ContentType = "application/x-www-form-urlencoded";
        httpContext.Request.Form = new FormCollection(form);
    }
    var descriptor = new ActionDescriptor
    {
        Parameters = [new ParameterDescriptor { Name = argumentName, ParameterType = model.GetType() }]
    };
    var actionContext = new ActionContext(httpContext, new RouteData(), descriptor, new ModelStateDictionary());
    var executing = new ActionExecutingContext(actionContext, [],
        new Dictionary<string, object?> { [argumentName] = model }, new object());
    var ran = false;
    await filter.OnActionExecutionAsync(executing, () =>
    {
        ran = true;
        return Task.FromResult(new ActionExecutedContext(actionContext, [], executing.Controller));
    });
    Check(ran == (executing.Result is null), "Rejected requests stop before the action; accepted requests continue.");
    return ran;
}

foreach (var model in new object[]
{
    new LoginViewModel(), new AddAdminViewModel(), new EditAdminViewModel(),
    new AddJuryViewModel(), new EditJuryViewModel()
})
{
    var passwordMetadata = metadataProvider.GetMetadataForType(model.GetType()).Properties[nameof(LoginViewModel.Password)];
    Check(passwordMetadata?.DataTypeName == "Password", "Every real credential model declares password metadata.");
    model.GetType().GetProperty("Password")!.SetValue(model, exactPassword);
    Check(await Accepted(model, new() { ["Password"] = exactPassword }), "Opaque credentials pass raw-form and bound-model checks.");
    Check((string?)model.GetType().GetProperty("Password")!.GetValue(model) == exactPassword, "Filtering never mutates the credential value.");
}

foreach (var password in new[] { "Abcd123<>", "Abcd123&lt;", "Abcd123onx=", "<script>alert(1)</script>", " \tİıI i<> ", "\0opaque" })
{
    var model = new LoginViewModel { Username = "safe", Password = password };
    Check(await Accepted(model, new() { ["Password"] = password }), "Credential punctuation/control values stay opaque.");
    Check(await Accepted(model), "Password metadata also applies when inspecting only the bound model.");
    Check(model.Password == password, "Exact credential characters survive both filter passes.");
}

Check(await Accepted(new LoginViewModel { Password = exactPassword }, new() { ["model.Password"] = exactPassword }), "MVC parameter-prefixed credentials are exempt.");
Check(await Accepted(new LoginViewModel { Password = exactPassword }, new() { ["MODEL.pAssword"] = exactPassword }), "Credential field matching follows MVC's case-insensitive binding.");
Check(!await Accepted(new LoginViewModel { Password = exactPassword }, new()
    { ["model.Password"] = exactPassword, ["Password"] = "<img src=x>" }), "An unbound unprefixed value is not exempt when MVC selects a prefix.");
Check(!await Accepted(new LoginViewModel { Password = exactPassword }, new()
    { ["Password"] = exactPassword, ["Unknown"] = "<img src=x>" }), "Unknown form fields still reject HTML.");
Check(!await Accepted(new LoginViewModel { Password = exactPassword, Username = "<script>" }, new()
    { ["Password"] = exactPassword, ["Username"] = "<script>" }), "Other raw form values retain HTML filtering.");
Check(!await Accepted(new LoginViewModel { Password = exactPassword, Username = "<script>" }), "Other bound model properties retain HTML filtering.");
Check(!await Accepted(new LoginViewModel { Password = exactPassword },
    new() { ["Password"] = exactPassword }, query: "?Other=%3Cscript%3E"), "Query values retain HTML filtering.");
Check(!await Accepted(new LoginViewModel { Password = exactPassword },
    new() { ["Password"] = exactPassword }, query: "?Password=%3Cscript%3E"), "A credential form exemption never exempts unbound query input.");
Check(!await Accepted(new PlainTextModel { Password = "<script>" }, new() { ["Password"] = "<script>" }), "A property named Password without metadata gets no exemption.");
Check(!await Accepted(new NotBoundCredential(), new() { ["Password"] = "<script>" }), "BindNever password properties do not exempt raw request values.");
Check(await Accepted(new AliasedCredential { Password = exactPassword }, new() { ["secret"] = exactPassword }), "Password property aliases follow MVC binding metadata.");
Check(await Accepted(new NestedCredentials { Child = new() { Password = exactPassword } }, new()
    { ["Child.Password"] = exactPassword }), "Nested credential paths are recognized.");
Check(await Accepted(new CredentialCollection { Children = [new() { Password = exactPassword }] }, new()
    { ["Children[0].Password"] = exactPassword }), "Indexed credential paths are recognized.");

Console.WriteLine($"PASS: {assertions} credential compatibility and MVC filter assertions; no database connection used.");

sealed class PlainTextModel { public string Password { get; set; } = ""; }
sealed class NotBoundCredential
{
    [BindNever, DataType(DataType.Password)] public string Password { get; set; } = "";
}
sealed class AliasedCredential
{
    [FromForm(Name = "secret"), DataType(DataType.Password)] public string Password { get; set; } = "";
}
sealed class NestedCredentials { public LoginViewModel Child { get; set; } = new(); }
sealed class CredentialCollection { public List<LoginViewModel> Children { get; set; } = []; }
