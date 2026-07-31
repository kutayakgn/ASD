using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("FormLifecycleStates")]
public sealed class FormLifecycleState
{
    [Key]
    public Guid Id { get; set; }
    public Guid FormId { get; set; }
    public string EntityName { get; set; } = null!;
    public Guid EntityId { get; set; }
    public bool WasPublished { get; set; }
    public bool? WasActive { get; set; }
    public bool? WasJuriOylamaStatus { get; set; }
    public bool? WasKunyeGirisStatus { get; set; }
    public int? WasStatusCode { get; set; }
    public DateTime DeactivatedAt { get; set; }
    public DateTime? RestoredAt { get; set; }
    public bool IsPublished { get; set; } = true;

    public Form Form { get; set; } = null!;
}