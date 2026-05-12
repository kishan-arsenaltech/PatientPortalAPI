using PatientPortalAPI.Core.Application.Interfaces;
using PatientPortalAPI.Core.Domain;
using PatientPortalAPI.Infrastructure.Data;
using Dapper;

namespace PatientPortalAPI.Infrastructure.Data.Repositories;

public interface IOrderRepository : IGenericRepository<Order>
{
    Task<IEnumerable<Order>> GetByPatientIdAsync(Guid patientId);
}

public class OrderRepository(IDbConnectionFactory connectionFactory) : GenericRepository<Order>(connectionFactory), IOrderRepository
{
    public async Task<IEnumerable<Order>> GetByPatientIdAsync(Guid patientId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var sql = "SELECT * FROM [clinical].[Orders] WHERE PatientID = @PatientId AND DeletedAt IS NULL";
        return await connection.QueryAsync<Order>(sql, new { PatientId = patientId });
    }
}
