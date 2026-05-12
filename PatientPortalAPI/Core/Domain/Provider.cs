using System.ComponentModel.DataAnnotations.Schema;

namespace PatientPortalAPI.Core.Domain;

[Table("Provider", Schema = "core")]
public class Provider : BaseEntity
{
    public Guid ProviderID { get; set; }
    public Guid? OrganizationID { get; set; }
    public Guid? UserID { get; set; }
    public string? Npi { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? Credentials { get; set; }
    public string? Specialty { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
}
