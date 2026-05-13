using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PatientPortalAPI.Core.Application.DTOs;
using PatientPortalAPI.Infrastructure.Security;
using PatientPortalAPI.Core.Application.Interfaces;

namespace PatientPortalAPI.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController(
    IJwtProvider jwtProvider, 
    IAuthRepository authRepository) : ControllerBase
{
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var user = await authRepository.GetUserWithCredentialByEmailAsync(request.Email);

        if (user == null) return Unauthorized("Invalid credentials.");

        bool isPasswordValid = BCrypt.Net.BCrypt.Verify(request.Password, (string)user.PasswordHash);
        if (!isPasswordValid) return Unauthorized("Invalid credentials.");

        // Mocking roles for now
        var roles = new List<string> { "Provider", "Staff" };

        var token = jwtProvider.GenerateToken(user.UserID, user.Email, user.TenantID, roles);

        return Ok(new LoginResponse(token, user.Email, user.FullName));
    }

    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        try
        {
            var passwordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);
            var userId = await authRepository.RegisterUserAsync(request, passwordHash);

            return Ok(new { Message = "User registered successfully.", UserID = userId });
        }
        catch (Exception ex)
        {
            return BadRequest(new { Message = "Registration failed.", Error = ex.Message });
        }
    }
}
