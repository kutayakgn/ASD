using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace YkbAfife.Business.Service.JuryVoting;

public static class JuryPasswordResetRegistration
{
    public static IServiceCollection AddJuryPasswordReset(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddOptions<JuryVotingPasswordResetOptions>()
            .Bind(configuration.GetSection(JuryVotingPasswordResetOptions.SectionName))
            .ValidateDataAnnotations()
            .Validate(options => Uri.TryCreate(options.PublicBaseUrl, UriKind.Absolute, out var uri)
                                 && uri.Scheme == Uri.UriSchemeHttps,
                "JuryVotingPasswordReset:PublicBaseUrl mutlak bir HTTPS adresi olmalıdır.")
            .ValidateOnStart();

        services.AddHttpClient<IJuryVotingMailSender, MicrosoftGraphJuryVotingMailSender>(client =>
        {
            client.Timeout = TimeSpan.FromSeconds(15);
        });
        services.AddSingleton<JuryVotingMailQueue>();
        services.AddSingleton<IJuryVotingMailQueue>(provider => provider.GetRequiredService<JuryVotingMailQueue>());
        services.AddHostedService<JuryVotingMailQueue>(provider => provider.GetRequiredService<JuryVotingMailQueue>());

        services.AddRateLimiter(options =>
        {
            options.AddPolicy("jury-forgot-password", httpContext =>
                RateLimitPartition.GetFixedWindowLimiter(
                    httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 5,
                        Window = TimeSpan.FromMinutes(5),
                        QueueLimit = 0,
                        AutoReplenishment = true
                    }));
        });

        return services;
    }
}
