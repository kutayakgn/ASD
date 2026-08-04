using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("Announcements")]
public class Announcement
{
    [Key]
    public Guid Id { get; set; }
    public int AnnouncementLocationId { get; set; }
    public string? Text { get; set; }
    public string? ButtonText { get; set; }
    public string? ButtonLink { get; set; }
    public Guid? ImageId { get; set; }
    public Guid? BackgroundImageId { get; set; }
    public string? BackgroundColor { get; set; }
    public DateTime? CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsPublished { get; set; }

    public Image? ImageAsset { get; set; }
    public Image? BackgroundImageAsset { get; set; }
}