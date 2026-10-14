namespace YkbAfife.Business.Service.JuryVoting;

public interface IJuryVotingMailSender
{
    Task SendPasswordResetAsync(
        string recipientEmail,
        string recipientName,
        string resetLink,
        CancellationToken cancellationToken = default);
}
