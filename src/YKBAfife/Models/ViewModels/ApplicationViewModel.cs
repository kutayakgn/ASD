using System.ComponentModel.DataAnnotations;
using YKBAfife.Models.Components;

namespace YKBAfife.Models.ViewModels;

public sealed class ApplicationTableQuery
{
    public string Search { get; set; } = string.Empty;
    public string SortBy { get; set; } = ApplicationSortColumns.CreatedDate;
    public string SortDirection { get; set; } = "desc";
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 10;
}

public sealed class ApplicationTableViewModel
{
    public string Search { get; init; } = string.Empty;
    public string SortBy { get; init; } = ApplicationSortColumns.CreatedDate;
    public string SortDirection { get; init; } = "desc";
    public int CurrentPage { get; init; } = 1;
    public int PageSize { get; init; } = 10;
    public int TotalCount { get; init; }
    public IReadOnlyList<ApplicationRowViewModel> Rows { get; init; } = [];
}

public sealed class ApplicationRowViewModel
{
    public Guid Id { get; init; }
    public string ApplicationNumber { get; init; } = string.Empty;
    public string PlayName { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string Phone { get; init; } = string.Empty;
    public DateTime? CreatedDate { get; init; }
    public bool IsActive { get; init; }
}

public sealed class ApplicationsViewModel
{
    public ComplexTableViewModel Table { get; init; } = new();
}

public sealed class ApplicationDetailsViewModel
{
    public Guid Id { get; init; }
    public string ApplicationNumber { get; init; } = string.Empty;
    public string PlayName { get; init; } = string.Empty;
    public string TheatreName { get; init; } = string.Empty;
    public string ApplicantName { get; init; } = string.Empty;
    public string ApplicantRole { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string Phone { get; init; } = string.Empty;
    public string? ContactName { get; init; }
    public string? ContactPhone { get; init; }
    public DateOnly PremiereDate { get; init; }
    public bool IsActive { get; init; }
}

public sealed class EditApplicationViewModel
{
    public Guid Id { get; set; }

    [Required(ErrorMessage = "Başvuru no zorunludur.")]
    [StringLength(6, ErrorMessage = "Başvuru no 6 karakterden uzun olamaz.")]
    [Display(Name = "Başvuru No")]
    public string ApplicationNumber { get; set; } = string.Empty;

    [Required(ErrorMessage = "Statü seçimi zorunludur.")]
    [Display(Name = "Statü")]
    public bool? IsActive { get; set; }

    [Required(ErrorMessage = "Oyun adı zorunludur.")]
    [StringLength(500, ErrorMessage = "Oyun adı 500 karakterden uzun olamaz.")]
    [Display(Name = "Oyun Adı")]
    public string PlayName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Tiyatro adı zorunludur.")]
    [StringLength(500, ErrorMessage = "Tiyatro adı 500 karakterden uzun olamaz.")]
    [Display(Name = "Tiyatro Adı")]
    public string TheatreName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Prömiyer tarihi zorunludur.")]
    [Display(Name = "Prömiyer Tarihi")]
    public DateOnly? PremiereDate { get; set; }

    [Required(ErrorMessage = "Adı soyadı zorunludur.")]
    [StringLength(100, ErrorMessage = "Adı soyadı 100 karakterden uzun olamaz.")]
    [Display(Name = "Adı Soyadı")]
    public string ApplicantName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Görevi zorunludur.")]
    [StringLength(200, ErrorMessage = "Görevi 200 karakterden uzun olamaz.")]
    [Display(Name = "Görevi")]
    public string ApplicantRole { get; set; } = string.Empty;

    [Required(ErrorMessage = "Telefon zorunludur.")]
    [Phone(ErrorMessage = "Geçerli bir telefon numarası giriniz.")]
    [StringLength(20, ErrorMessage = "Telefon 20 karakterden uzun olamaz.")]
    [Display(Name = "Telefon")]
    public string Phone { get; set; } = string.Empty;

    [Required(ErrorMessage = "E-posta zorunludur.")]
    [EmailAddress(ErrorMessage = "Geçerli bir e-posta adresi giriniz.")]
    [StringLength(150, ErrorMessage = "E-posta 150 karakterden uzun olamaz.")]
    [Display(Name = "E-posta")]
    public string Email { get; set; } = string.Empty;

    [StringLength(100, ErrorMessage = "İletişim kurulacak kişi 100 karakterden uzun olamaz.")]
    [Display(Name = "İletişim Kurulacak Kişi")]
    public string? ContactName { get; set; }

    [Phone(ErrorMessage = "Geçerli bir iletişim telefonu giriniz.")]
    [StringLength(20, ErrorMessage = "İletişim kurulacak telefon 20 karakterden uzun olamaz.")]
    [Display(Name = "İletişim Kurulacak Telefon")]
    public string? ContactPhone { get; set; }
}

public static class ApplicationSortColumns
{
    public const string ApplicationNumber = "applicationNumber";
    public const string Play = "play";
    public const string Email = "email";
    public const string Phone = "phone";
    public const string CreatedDate = "createdDate";
    public const string Status = "status";
}
