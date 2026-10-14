using DocumentFormat.OpenXml.Math;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Server.IIS;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Migrations;
using YKBAfife.Data;
using YKBAfife.Data.Migrations;
using YKBAfife.Helpers;
using YKBAfife.Services.Audit;
using YKBAfife.Services.Authentication;
using YKBAfife.Services.Exports;
using YKBAfife.Services.Reports;
using YKBAfife.Services.Security;

var builder = WebApplication.CreateBuilder(args);

builder.WebHost.ConfigureKestrel(options =>
    options.Limits.MaxRequestBodySize = ImageUploadPolicy.MaximumRequestBodySizeBytes);
builder.Services.Configure<IISServerOptions>(options =>
    options.MaxRequestBodySize = ImageUploadPolicy.MaximumRequestBodySizeBytes);
builder.Services.Configure<FormOptions>(options =>
    options.MultipartBodyLengthLimit = ImageUploadPolicy.MaximumRequestBodySizeBytes);

builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

builder.Services.AddControllersWithViews(options =>
{
    options.Filters.Add<UnsafeInputValidationFilter>();
    options.Filters.Add<AdminActionAuditFilter>();
});

var connectionString = builder.Configuration.GetConnectionString("AfifeConnectionString")
    ?? throw new InvalidOperationException("Connection string 'AfifeConnectionString' was not found.");

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<AdminAuditConnectionInterceptor>();
builder.Services.AddScoped<AdminActionAuditFilter>();
builder.Services.AddScoped<UnsafeInputValidationFilter>();
builder.Services.AddScoped<IAdminActionAuditLogger, AdminActionAuditLogger>();
builder.Services.AddDbContext<AfifeContext>((serviceProvider, options) =>
    options
        .UseSqlServer(connectionString)
        .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>()
        .AddInterceptors(serviceProvider.GetRequiredService<AdminAuditConnectionInterceptor>()));
builder.Services.AddHostedService<DatabaseMigrationHostedService>();
builder.Services.AddScoped<IUserActivityLogger, UserActivityLogger>();
builder.Services.AddScoped<IAdminAuthenticationService, AdminAuthenticationService>();
builder.Services.AddScoped<IPlayWatchReportService, PlayWatchReportService>();
builder.Services.AddScoped<IPlayReportService, PlayReportService>();
builder.Services.AddScoped<ICandidateReportService, CandidateReportService>();
builder.Services.AddScoped<IRankingReportService, RankingReportService>();
builder.Services.AddScoped<IJuryReportService, JuryReportService>();
builder.Services.AddScoped<IAdminReportService, AdminReportService>();
builder.Services.AddScoped<IArchiveComparisonReportService, ArchiveComparisonReportService>();
builder.Services.AddScoped<ISeasonSettingsReportService, SeasonSettingsReportService>();
builder.Services.AddScoped<IAdditionalVotingReportService, AdditionalVotingReportService>();
builder.Services.AddScoped<ITicketSalesReportService, TicketSalesReportService>();
builder.Services.AddScoped<IBlacklistReportService, BlacklistReportService>();
builder.Services.AddScoped<IApplicationReportService, ApplicationReportService>();
builder.Services.AddScoped<IJuryWatchedPlayReportService, JuryWatchedPlayReportService>();
builder.Services.AddSingleton<IExcelExporter, ExcelExporter>();

builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = "AfifeAdmin.Authentication";
        options.Cookie.HttpOnly = true;
        options.Cookie.IsEssential = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.LoginPath = "/giris-yap";
        options.AccessDeniedPath = "/giris-yap";
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = true;
    });

builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

var app = builder.Build();

app.Use(async (context, next) =>
{
    context.Response.OnStarting(() =>
    {
        var headers = context.Response.Headers;
        headers["Content-Security-Policy"] =
            "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; " +
            "img-src 'self' data: blob:; font-src 'self' data:; object-src 'none'; " +
            "base-uri 'self'; frame-ancestors 'none'; form-action 'self'";
        headers["X-Content-Type-Options"] = "nosniff";
        headers["X-Frame-Options"] = "DENY";
        headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
        headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
        return Task.CompletedTask;
    });

    await next();
});

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();


//# Entity/configuration/SQL değişikliklerini yaptıktan sonra:
//powershell - ExecutionPolicy Bypass - File scripts / migration.ps1 add AddUserNote

//# Üretilen Up/Down işlemlerini inceleyin, ardından:
//powershell - ExecutionPolicy Bypass -File scripts/test-migration-deployment.ps1 -Configuration Release

//# Kaynak kodu normal deploy edin; uygulama bekleyen migration'ları uygular.