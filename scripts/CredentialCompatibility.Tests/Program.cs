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
