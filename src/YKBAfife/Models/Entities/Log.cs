using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("Log")]
public class Log
{
    [Key]
    public int Id { get; set; }
    public string Title { get; set; } = null!;
    public string Source { get; set; } = null!;
    public string EventType { get; set; } = null!;
    public string Message { get; set; } = null!;
    public DateTime? CreatedDate { get; set; }
    public bool IsPublished { get; set; }
}
