namespace YKBAfife.Models.Components;

public sealed class GenericPopupViewModel
{
    public string InitialType { get; init; } = string.Empty;
    public string InitialMessage { get; init; } = string.Empty;
    public string InitialRedirectUrl { get; init; } = string.Empty;
    public bool IsInitiallyOpen => !string.IsNullOrWhiteSpace(InitialType) &&
                                   !string.IsNullOrWhiteSpace(InitialMessage);
}

public static class GenericPopupTypes
{
    public const string Question = "question";
    public const string Success = "success";
    public const string Fail = "fail";
}
