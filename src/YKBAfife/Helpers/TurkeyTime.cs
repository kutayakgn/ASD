namespace YKBAfife.Helpers;

public static class TurkeyTime
{
    private static readonly TimeSpan TurkeyUtcOffset = TimeSpan.FromHours(3);

    public static DateTime Now =>
        DateTime.SpecifyKind(DateTime.UtcNow.Add(TurkeyUtcOffset), DateTimeKind.Unspecified);
}
