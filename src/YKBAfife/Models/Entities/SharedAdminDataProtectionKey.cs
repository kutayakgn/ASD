namespace YKBAfife.Models.Entities;

/// <summary>Append-only framework key/revocation XML shared by admin nodes.</summary>
public sealed class SharedAdminDataProtectionKey
{
    public Guid Id { get; set; }
    public string? FriendlyName { get; set; }
    public string Xml { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
    public bool IsPublished { get; set; } = true;
}
