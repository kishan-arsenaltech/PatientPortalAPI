using PatientPortalAPI.Models;

namespace PatientPortalAPI.Services.Interfaces
{
    public interface IAuthService
    {
        Task<LoginResponse?> LoginAsync(LoginRequest request);
    }
}
