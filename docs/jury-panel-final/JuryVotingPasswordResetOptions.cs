using System.ComponentModel.DataAnnotations;

namespace YkbAfife.Business.Service.JuryVoting;

public sealed class JuryVotingPasswordResetOptions
{
    public const string SectionName = "JuryVotingPasswordReset";

    [Required, Url]
    public string PublicBaseUrl { get; init; } = string.Empty;

    [Range(5, 5)]
    public int TokenLifetimeMinutes { get; init; } = 5;

    [Range(30, 600)]
    public int MinimumRequestIntervalSeconds { get; init; } = 60;

    [Required]
    public MicrosoftGraphMailOptions MicrosoftGraphMail { get; init; } = new();
}

public sealed class MicrosoftGraphMailOptions
{
    [Required]
    public string TenantId { get; init; } = string.Empty;

    [Required]
    public string ClientId { get; init; } = string.Empty;

    [Required]
    public string ClientSecret { get; init; } = string.Empty;

    [Required, EmailAddress]
    public string FromEmail { get; init; } = string.Empty;
}
