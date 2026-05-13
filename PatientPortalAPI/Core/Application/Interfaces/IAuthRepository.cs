using PatientPortalAPI.Core.Application.DTOs;

namespace PatientPortalAPI.Core.Application.Interfaces;

public interface IAuthRepository
{
    Task<dynamic?> GetUserWithCredentialByEmailAsync(string email);
    Task<Guid> RegisterUserAsync(RegisterRequest request, string passwordHash);
}
