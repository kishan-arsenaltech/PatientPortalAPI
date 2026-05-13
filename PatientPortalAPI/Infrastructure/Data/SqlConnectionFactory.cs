using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace PatientPortalAPI.Infrastructure.Data;

public class SqlConnectionFactory(IConfiguration configuration) : IDbConnectionFactory
{
    private readonly string _connectionString = configuration.GetConnectionString("DefaultConnection") 
        ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");

    public IDbConnection CreateConnection()
    {
        var connection = new SqlConnection(_connectionString);
        return connection;
    }
}
