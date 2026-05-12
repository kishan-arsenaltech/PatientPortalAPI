using PatientPortalAPI.Core.Domain;

namespace PatientPortalAPI.Infrastructure.Security;

public interface IJwtProvider
{
    string GenerateToken(Guid userId, string email, Guid tenantId, IEnumerable<string> roles);
}
