using PatientPortalAPI.Core.Application.Interfaces;
using PatientPortalAPI.Core.Domain;
using PatientPortalAPI.Infrastructure.Data;
using Dapper;

namespace PatientPortalAPI.Infrastructure.Data.Repositories;

public interface IProviderRepository : IGenericRepository<Provider>
{
    Task<Provider?> GetByNpiAsync(string npi);
}

public class ProviderRepository(IDbConnectionFactory connectionFactory) : GenericRepository<Provider>(connectionFactory), IProviderRepository
{
    public async Task<Provider?> GetByNpiAsync(string npi)
    {
        using var connection = _connectionFactory.CreateConnection();
        var sql = "SELECT * FROM [core].[Provider] WHERE Npi = @Npi AND DeletedAt IS NULL";
        return await connection.QuerySingleOrDefaultAsync<Provider>(sql, new { Npi = npi });
    }
}
