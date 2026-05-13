using PatientPortalAPI.Core.Application.Interfaces;
using PatientPortalAPI.Core.Domain;
using PatientPortalAPI.Infrastructure.Data;
using Dapper;

namespace PatientPortalAPI.Infrastructure.Data.Repositories;

public interface IReferralRepository : IGenericRepository<Referral>
{
    Task<IEnumerable<Referral>> GetPendingReferralsAsync();
}

public class ReferralRepository(IDbConnectionFactory connectionFactory) : GenericRepository<Referral>(connectionFactory), IReferralRepository
{
    public async Task<IEnumerable<Referral>> GetPendingReferralsAsync()
    {
        using var connection = _connectionFactory.CreateConnection();
        var sql = "SELECT * FROM [intake].[Referral] WHERE ReferralStatus IN ('NEW', 'PENDING') AND DeletedAt IS NULL";
        return await connection.QueryAsync<Referral>(sql);
    }
}
