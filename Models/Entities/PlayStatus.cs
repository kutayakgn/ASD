using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("PlayStatuses")]
public class PlayStatus
{
    [Key]
    public Guid Id { get; set; }
    public string StatusName { get; set; } = null!;
    public int StatusCode { get; set; }
    public DateTime? CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsPublished { get; set; }
    public string? StatusColor { get; set; }

    public ICollection<Play> Plays { get; set; } = [];
}
