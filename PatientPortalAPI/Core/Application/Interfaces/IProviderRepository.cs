using PatientPortalAPI.Core.Domain;

namespace PatientPortalAPI.Core.Application.Interfaces;

public interface IProviderRepository : IGenericRepository<Provider>
{
    Task<Provider?> GetByNpiAsync(string npi);
}
