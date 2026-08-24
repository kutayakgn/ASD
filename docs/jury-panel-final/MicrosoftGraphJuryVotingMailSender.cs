using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace YkbAfife.Business.Service.JuryVoting;

public sealed class MicrosoftGraphJuryVotingMailSender : IJuryVotingMailSender
{
    private readonly HttpClient _httpClient;
    private readonly JuryVotingPasswordResetOptions _options;

    public MicrosoftGraphJuryVotingMailSender(
        HttpClient httpClient,
        IOptions<JuryVotingPasswordResetOptions> options)
    {
        _httpClient = httpClient;
        _options = options.Value;
    }

    public async Task SendPasswordResetAsync(
        string recipientEmail,
        string recipientName,
        string resetLink,
        CancellationToken cancellationToken = default)
    {
        var accessToken = await GetAccessTokenAsync(cancellationToken);
        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://graph.microsoft.com/v1.0/users/{Uri.EscapeDataString(_options.MicrosoftGraphMail.FromEmail)}/sendMail");

        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        request.Content = JsonContent.Create(new
        {
            message = new
            {
                subject = "Afife Jüri Oylama - Şifre Sıfırlama",
                body = new
                {
                    contentType = "HTML",
                    content = BuildBody(recipientName, resetLink)
                },
                toRecipients = new[]
                {
                    new { emailAddress = new { address = recipientEmail } }
                }
            },
            saveToSentItems = false
        });

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();
    }

    private async Task<string> GetAccessTokenAsync(CancellationToken cancellationToken)
    {
        var mail = _options.MicrosoftGraphMail;
        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://login.microsoftonline.com/{Uri.EscapeDataString(mail.TenantId)}/oauth2/v2.0/token")
        {
            Content = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["client_id"] = mail.ClientId,
                ["client_secret"] = mail.ClientSecret,
                ["scope"] = "https://graph.microsoft.com/.default",
                ["grant_type"] = "client_credentials"
            })
        };

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        return document.RootElement.GetProperty("access_token").GetString()
               ?? throw new InvalidOperationException("Microsoft Graph access token response was empty.");
    }

    private static string BuildBody(string recipientName, string resetLink)
    {
        var safeName = System.Net.WebUtility.HtmlEncode(
            string.IsNullOrWhiteSpace(recipientName) ? "Değerli Kullanıcı" : recipientName);
        var safeLink = System.Net.WebUtility.HtmlEncode(resetLink);

        return $"<p>{safeName},</p>"
             + "<p>Şifrenizi sıfırlamak için aşağıdaki bağlantıya tıklayın.</p>"
             + $"<p><a href=\"{safeLink}\">Şifrenizi sıfırlayın</a></p>"
             + "<p>Bu bağlantı 5 dakika geçerlidir ve kullanıldıktan sonra tekrar kullanılamaz.</p>"
             + "<p>Bu işlemi siz istemediyseniz e-postayı dikkate almayın.</p>";
    }
}
