using System.ComponentModel.DataAnnotations.Schema;

namespace PatientPortalAPI.Core.Domain;

[Table("Patient", Schema = "patient")]
public class Patient : BaseEntity
{
    public Guid PatientID { get; set; }
    public Guid? OrganizationID { get; set; }
    [NotMapped]
    public string? PatientNumber { get; set; } // Computed in SQL
    [NotMapped]
    public int PatientSeq { get; set; } // Identity in SQL
    public string FirstName { get; set; } = string.Empty;
    public string? MiddleName { get; set; }
    public string LastName { get; set; } = string.Empty;
    public string? PreferredName { get; set; }
    public DateTime DateOfBirth { get; set; }
    public string? GenderCode { get; set; }
    public string? RaceCode { get; set; }
    public string? EthnicityCode { get; set; }
    public string? PreferredLanguage { get; set; }
    public string? MaritalStatus { get; set; }
    public string? SSNEncrypted { get; set; }
    public string? SSNLastFour { get; set; }
    public string? AddressLine1 { get; set; }
    public string? AddressLine2 { get; set; }
    public string? City { get; set; }
    public string? StateCode { get; set; }
    public string? ZipCode { get; set; }
    public string? County { get; set; }
    public string? Phone { get; set; }
    public string? PhoneMobile { get; set; }
    public string? Email { get; set; }
    public string PatientStatus { get; set; } = "ACTIVE";
    public bool IsDeceased { get; set; }
    public DateTime? DeceasedDate { get; set; }
    public string? ReferralSourceCode { get; set; }
    public string? MarketCode { get; set; }
    public string? BrightreePatientID { get; set; }
    public string? ExternalPatientID { get; set; }
    public string? Notes { get; set; }
    public bool IsActive { get; set; } = true;
    public Guid? CreatedByUserID { get; set; }
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public Guid? UpdatedByUserID { get; set; }
}
