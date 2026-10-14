using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace YkbAfife.Business.Service.JuryVoting;

public static class JuryPasswordResetRegistration
{
    public static IServiceCollection AddJuryPasswordReset(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddOptions<JuryVotingPasswordResetOptions>()
            .Bind(configuration.GetSection(JuryVotingPasswordResetOptions.SectionName));

        services.AddSingleton<IJuryForgotPasswordRequestLimiter, JuryForgotPasswordRequestLimiter>();

        var enabledValue = configuration[$"{JuryVotingPasswordResetOptions.SectionName}:Enabled"];
        var isEnabled = bool.TryParse(enabledValue, out var enabled) && enabled;
        if (!isEnabled)
        {
            services.AddSingleton<IJuryVotingMailQueue, DisabledJuryVotingMailQueue>();
            return services;
        }

        services.AddSingleton<IJuryVotingMailSender, MicrosoftGraphJuryVotingMailSender>();
        services.AddSingleton<JuryVotingMailQueue>();
        services.AddSingleton<IJuryVotingMailQueue>(provider => provider.GetRequiredService<JuryVotingMailQueue>());
        services.AddSingleton<IHostedService>(provider => provider.GetRequiredService<JuryVotingMailQueue>());

        return services;
    }
}
