using PatientPortalAPI.Core.Domain;

namespace PatientPortalAPI.Core.Application.Interfaces;

public interface IOrderRepository : IGenericRepository<Order>
{
    Task<IEnumerable<Order>> GetByPatientIdAsync(Guid patientId);
}
