using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("Form")]
public class Form
{
    [Key]
    public Guid Id { get; set; }
    public string ApplicationNumber { get; set; } = null!;
    public Guid SeasonId { get; set; }
    public DateTime? CreatedDate { get; set; }
    public DateTime? UpdatedDate { get; set; }
    public string RepertoireName { get; set; } = null!;
    public string TheatreName { get; set; } = null!;
    public DateOnly PremiereDate { get; set; }
    public string Display { get; set; } = null!;
    public string ApplicantName { get; set; } = null!;
    public string ApplicantRole { get; set; } = null!;
    public string Phone { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string Director { get; set; } = null!;
    public string? ContactName { get; set; }
    public string? ContactPhone { get; set; }
    public string? LeadActress { get; set; }
    public string? LeadActor { get; set; }
    public string? SupportActress { get; set; }
    public string? SupportActor { get; set; }
    public string? StageDesign { get; set; }
    public string? ClothesDesign { get; set; }
    public string? LightDesign { get; set; }
    public string? StageMusic { get; set; }
    public string? Choreography { get; set; }
    public bool IsActive { get; set; } = true;
    public bool IsPublished { get; set; } = true;

    public Season Season { get; set; } = null!;
    public Play? Play { get; set; }
}