namespace PatientPortalAPI.Core.Domain;

public abstract class BaseEntity
{
    public Guid TenantID { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public byte[]? RowVersion { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
}
