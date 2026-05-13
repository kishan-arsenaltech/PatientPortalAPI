using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using PatientPortalAPI.Core.Application.Constants;

namespace PatientPortalAPI.Infrastructure.Data;

public class SqlConnectionFactory(IConfiguration configuration) : IDbConnectionFactory
{
    private readonly string _connectionString = configuration[SecretKeys.SqlConnection] 
        ?? throw new InvalidOperationException($"Connection string '{SecretKeys.SqlConnection}' not found.");

    public IDbConnection CreateConnection()
    {
        var connection = new SqlConnection(_connectionString);
        return connection;
    }
}
