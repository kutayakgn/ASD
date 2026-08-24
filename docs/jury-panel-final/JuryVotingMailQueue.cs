using System.Threading.Channels;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace YkbAfife.Business.Service.JuryVoting;

public interface IJuryVotingMailQueue
{
    bool TryEnqueuePasswordReset(
        Guid tokenId,
        string recipientEmail,
        string recipientName,
        string resetLink);
}

public sealed class JuryVotingMailQueue : BackgroundService, IJuryVotingMailQueue
{
    private readonly Channel<PasswordResetMailItem> _channel = Channel.CreateBounded<PasswordResetMailItem>(
        new BoundedChannelOptions(100)
        {
            FullMode = BoundedChannelFullMode.Wait,
            SingleReader = true,
            SingleWriter = false
        });
    private readonly IJuryVotingMailSender _mailSender;
    private readonly ILogger<JuryVotingMailQueue> _logger;

    public JuryVotingMailQueue(
        IJuryVotingMailSender mailSender,
        ILogger<JuryVotingMailQueue> logger)
    {
        _mailSender = mailSender;
        _logger = logger;
    }

    public bool TryEnqueuePasswordReset(
        Guid tokenId,
        string recipientEmail,
        string recipientName,
        string resetLink)
    {
        return _channel.Writer.TryWrite(new PasswordResetMailItem(
            tokenId,
            recipientEmail,
            recipientName,
            resetLink));
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var item in _channel.Reader.ReadAllAsync(stoppingToken))
        {
            Exception? lastException = null;
            for (var attempt = 1; attempt <= 3; attempt++)
            {
                try
                {
                    await _mailSender.SendPasswordResetAsync(
                        item.RecipientEmail,
                        item.RecipientName,
                        item.ResetLink,
                        stoppingToken);
                    lastException = null;
                    break;
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    return;
                }
                catch (Exception exception)
                {
                    lastException = exception;
                    if (attempt < 3)
                    {
                        await Task.Delay(TimeSpan.FromSeconds(attempt), stoppingToken);
                    }
                }
            }

            if (lastException is not null)
            {
                // Kişisel veri ve ham token yerine yalnızca iç sistem kimliği loglanır.
                _logger.LogError(lastException,
                    "Queued jury password reset email could not be sent after retries. TokenId: {TokenId}",
                    item.TokenId);
            }
        }
    }

    private sealed record PasswordResetMailItem(
        Guid TokenId,
        string RecipientEmail,
        string RecipientName,
        string ResetLink);
}
