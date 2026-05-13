using PatientPortalAPI.Core.Application.Interfaces;
using PatientPortalAPI.Core.Domain;
using PatientPortalAPI.Infrastructure.Data;
using PatientPortalAPI.Infrastructure.Security;
using Dapper;

namespace PatientPortalAPI.Infrastructure.Data.Repositories;

public class PatientRepository(IDbConnectionFactory connectionFactory, IEncryptionService encryptionService) 
    : GenericRepository<Patient>(connectionFactory), IPatientRepository
{
    public override async Task<Guid> AddAsync(Patient entity)
    {
        if (!string.IsNullOrEmpty(entity.SSNEncrypted))
        {
            entity.SSNEncrypted = encryptionService.Encrypt(entity.SSNEncrypted);
        }
        return await base.AddAsync(entity);
    }

    public override async Task<bool> UpdateAsync(Patient entity)
    {
        if (!string.IsNullOrEmpty(entity.SSNEncrypted))
        {
            entity.SSNEncrypted = encryptionService.Encrypt(entity.SSNEncrypted);
        }
        return await base.UpdateAsync(entity);
    }

    public async Task<IEnumerable<Patient>> SearchByNameAsync(string searchTerm)
    {
        using var connection = _connectionFactory.CreateConnection();
        var sql = "SELECT * FROM [patient].[Patient] WHERE (FirstName LIKE @Search OR LastName LIKE @Search) AND DeletedAt IS NULL";
        return await connection.QueryAsync<Patient>(sql, new { Search = $"%{searchTerm}%" });
    }

    public async Task<Patient?> GetByPatientNumberAsync(string patientNumber)
    {
        using var connection = _connectionFactory.CreateConnection();
        var sql = "SELECT * FROM [patient].[Patient] WHERE PatientNumber = @PatientNumber AND DeletedAt IS NULL";
        return await connection.QuerySingleOrDefaultAsync<Patient>(sql, new { PatientNumber = patientNumber });
    }
}
