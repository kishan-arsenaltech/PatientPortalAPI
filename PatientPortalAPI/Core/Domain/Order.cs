using System.ComponentModel.DataAnnotations.Schema;

namespace PatientPortalAPI.Core.Domain;

[Table("Orders", Schema = "clinical")]
public class Order : BaseEntity
{
    public Guid OrderID { get; set; }
    public Guid PatientID { get; set; }
    public Guid? ProviderID { get; set; }
    public Guid? OrganizationID { get; set; }
    public string? OrderNumber { get; set; }
    public string OrderType { get; set; } = string.Empty;
    public string? HcpcsCode { get; set; }
    public string? IcdCodes { get; set; }
    public DateTime OrderDate { get; set; }
    public DateTime? SetupDate { get; set; }
    public DateTime? DischargeDate { get; set; }
    public string OrderStatus { get; set; } = "PENDING";
    public short Quantity { get; set; } = 1;
    public string? ResupplyFreq { get; set; }
    public string? Notes { get; set; }
    public string? ExternalOrderID { get; set; }
    public Guid? CreatedByUserID { get; set; }
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
