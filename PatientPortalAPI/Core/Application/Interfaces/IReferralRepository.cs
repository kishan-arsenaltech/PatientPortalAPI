using PatientPortalAPI.Core.Domain;

namespace PatientPortalAPI.Core.Application.Interfaces;

public interface IReferralRepository : IGenericRepository<Referral>
{
    Task<IEnumerable<Referral>> GetPendingReferralsAsync();
}
