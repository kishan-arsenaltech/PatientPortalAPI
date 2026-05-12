using System.Data;

namespace PatientPortalAPI.Infrastructure.Data;

public interface IDbConnectionFactory
{
    IDbConnection CreateConnection();
}
