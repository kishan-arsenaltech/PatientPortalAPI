using PatientPortalAPI.Models;

namespace PatientPortalAPI.Repository.Interfaces
{
    public interface IAuthRepository
    {
        Task<UserModel?> LoginAsync(LoginRequest request);
    }
}
