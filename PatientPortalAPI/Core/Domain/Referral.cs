using System.ComponentModel.DataAnnotations.Schema;

namespace PatientPortalAPI.Core.Domain;

[Table("Referral", Schema = "intake")]
public class Referral : BaseEntity
{
    public Guid ReferralID { get; set; }
    public Guid? OrganizationID { get; set; }
    public string? ReferralNumber { get; set; }
    public string SourceType { get; set; } = string.Empty;
    public string ReferralStatus { get; set; } = "NEW";
    public string Priority { get; set; } = "NORMAL";
    public Guid? PatientID { get; set; }
    public Guid? ProviderID { get; set; }
    public string? IntakeFirstName { get; set; }
    public string? IntakeLastName { get; set; }
    public DateTime? IntakeDOB { get; set; }
    public string? IntakePhone { get; set; }
    public string? IntakeInsuranceID { get; set; }
    public string? IntakeInsuranceName { get; set; }
    public string? OrderType { get; set; }
    public string? DiagnosisCodes { get; set; }
    public string? PrescriberName { get; set; }
    public string? PrescriberNpi { get; set; }
    public string? ClinicalNotes { get; set; }
    public string? FaxNumber { get; set; }
    public DateTimeOffset ReceivedAt { get; set; }
    public Guid? AssignedToUserID { get; set; }
    public DateTimeOffset? DueDate { get; set; }
    public DateTimeOffset? ClosedAt { get; set; }
    public Guid? ClosedByUserID { get; set; }
    public string? ClosureReason { get; set; }
    public Guid? CreatedByUserID { get; set; }
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
