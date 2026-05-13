using PatientPortalAPI.Core.Domain;

namespace PatientPortalAPI.Core.Application.Interfaces;

public interface IPatientRepository : IGenericRepository<Patient>
{
    Task<IEnumerable<Patient>> SearchByNameAsync(string searchTerm);
    Task<Patient?> GetByPatientNumberAsync(string patientNumber);
}
