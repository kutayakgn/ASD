namespace YKBAfife.Models.Components;

public sealed class HeaderViewModel
{
    public required string UserFullName { get; init; }
    public bool ShowNavigation { get; init; } = true;
}
