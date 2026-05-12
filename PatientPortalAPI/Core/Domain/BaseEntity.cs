namespace PatientPortalAPI.Core.Domain;

public abstract class BaseEntity
{
    public Guid TenantID { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public Guid? CreatedByUserID { get; set; }
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public Guid? UpdatedByUserID { get; set; }
    public byte[]? RowVersion { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
}
