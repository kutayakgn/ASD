using System.ComponentModel.DataAnnotations;

namespace YkbAfife.Business.Service.JuryVoting;

public sealed class JuryVotingPasswordResetOptions
{
    public const string SectionName = "JuryVotingPasswordReset";

    public bool Enabled { get; set; }

    [Required, Url]
    public string PublicBaseUrl { get; set; } = string.Empty;

    [Range(5, 5)]
    public int TokenLifetimeMinutes { get; set; } = 5;

    [Range(30, 600)]
    public int MinimumRequestIntervalSeconds { get; set; } = 60;

    [Required]
    public MicrosoftGraphMailOptions MicrosoftGraphMail { get; set; } = new();

    public void EnsureValid()
    {
        if (!Enabled)
        {
            return;
        }

        if (!Uri.TryCreate(PublicBaseUrl, UriKind.Absolute, out var uri)
            || uri.Scheme != Uri.UriSchemeHttps)
        {
            throw new InvalidOperationException(
                "JuryVotingPasswordReset:PublicBaseUrl mutlak bir HTTPS adresi olmalıdır.");
        }

        if (TokenLifetimeMinutes != 5)
        {
            throw new InvalidOperationException(
                "JuryVotingPasswordReset:TokenLifetimeMinutes güvenlik nedeniyle 5 olmalıdır.");
        }

        if (MinimumRequestIntervalSeconds < 30 || MinimumRequestIntervalSeconds > 600)
        {
            throw new InvalidOperationException(
                "JuryVotingPasswordReset:MinimumRequestIntervalSeconds 30-600 arasında olmalıdır.");
        }

        if (MicrosoftGraphMail is null
            || string.IsNullOrWhiteSpace(MicrosoftGraphMail.TenantId)
            || string.IsNullOrWhiteSpace(MicrosoftGraphMail.ClientId)
            || string.IsNullOrWhiteSpace(MicrosoftGraphMail.ClientSecret)
            || string.IsNullOrWhiteSpace(MicrosoftGraphMail.FromEmail))
        {
            throw new InvalidOperationException(
                "JuryVotingPasswordReset:MicrosoftGraphMail ayarları eksiksiz tanımlanmalıdır.");
        }
    }
}

public sealed class MicrosoftGraphMailOptions
{
    [Required]
    public string TenantId { get; set; } = string.Empty;

    [Required]
    public string ClientId { get; set; } = string.Empty;

    [Required]
    public string ClientSecret { get; set; } = string.Empty;

    [Required, EmailAddress]
    public string FromEmail { get; set; } = string.Empty;
}
