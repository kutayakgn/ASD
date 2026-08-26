using System.Collections.Concurrent;

namespace YkbAfife.Business.Service.JuryVoting;

public interface IJuryForgotPasswordRequestLimiter
{
    bool TryAcquire(string? remoteIpAddress);
}

public sealed class JuryForgotPasswordRequestLimiter : IJuryForgotPasswordRequestLimiter
{
    private const int PermitLimit = 5;
    private static readonly TimeSpan Window = TimeSpan.FromMinutes(5);
    private readonly ConcurrentDictionary<string, Counter> _counters = new(StringComparer.Ordinal);

    public bool TryAcquire(string? remoteIpAddress)
    {
        var nowUtc = DateTime.UtcNow;
        var key = string.IsNullOrWhiteSpace(remoteIpAddress) ? "unknown" : remoteIpAddress;
        var counter = _counters.GetOrAdd(key, _ => new Counter(nowUtc));

        lock (counter.Gate)
        {
            if (nowUtc - counter.WindowStartedAtUtc >= Window)
            {
                counter.WindowStartedAtUtc = nowUtc;
                counter.Count = 0;
            }

            if (counter.Count >= PermitLimit)
            {
                return false;
            }

            counter.Count++;
        }

        RemoveExpiredCounters(nowUtc);
        return true;
    }

    private void RemoveExpiredCounters(DateTime nowUtc)
    {
        if (_counters.Count < 1024)
        {
            return;
        }

        foreach (var item in _counters)
        {
            if (nowUtc - item.Value.WindowStartedAtUtc >= Window + Window)
            {
                _counters.TryRemove(item.Key, out _);
            }
        }
    }

    private sealed class Counter
    {
        public Counter(DateTime windowStartedAtUtc)
        {
            WindowStartedAtUtc = windowStartedAtUtc;
        }

        public object Gate { get; } = new();
        public DateTime WindowStartedAtUtc { get; set; }
        public int Count { get; set; }
    }
}
