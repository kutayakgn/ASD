using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Services.Authentication;
using YKBAfife.Services.Audit;
using YKBAfife.Services.Exports;
using YKBAfife.Services.Reports;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();

var connectionString = builder.Configuration.GetConnectionString("AfifeAdmin")
    ?? throw new InvalidOperationException("Connection string 'AfifeAdmin' was not found.");

builder.Services.AddDbContext<AfifeContext>(options => options.UseSqlServer(connectionString));
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IUserActivityLogger, UserActivityLogger>();
builder.Services.AddScoped<IAdminAuthenticationService, AdminAuthenticationService>();
builder.Services.AddScoped<IPlayWatchReportService, PlayWatchReportService>();
builder.Services.AddScoped<IJuryReportService, JuryReportService>();
builder.Services.AddScoped<IAdminReportService, AdminReportService>();
builder.Services.AddScoped<IArchiveComparisonReportService, ArchiveComparisonReportService>();
builder.Services.AddScoped<ITicketSalesReportService, TicketSalesReportService>();
builder.Services.AddScoped<IBlacklistReportService, BlacklistReportService>();
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