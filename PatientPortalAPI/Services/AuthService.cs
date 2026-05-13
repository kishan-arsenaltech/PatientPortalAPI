using PatientPortalAPI.Helpers;
using PatientPortalAPI.Models;
using PatientPortalAPI.Repository.Interfaces;
using PatientPortalAPI.Services.Interfaces;

namespace PatientPortalAPI.Services
{
    public class AuthService : IAuthService
    {
        private readonly IAuthRepository _authRepository;

        private readonly JwtHelper _jwtHelper;

        public AuthService(
            IAuthRepository authRepository,
            JwtHelper jwtHelper)
        {
            _authRepository = authRepository;
            _jwtHelper = jwtHelper;
        }

        public async Task<LoginResponse?> LoginAsync(LoginRequest request)
        {
            var user = await _authRepository.LoginAsync(request);

            if (user == null)
            {
                return null;
            }

            string token = _jwtHelper.GenerateToken(user);

            return new LoginResponse
            {
                UserId = user.UserId,
                Token = token,
                Username = user.UserName
            };
        }
    }
}
