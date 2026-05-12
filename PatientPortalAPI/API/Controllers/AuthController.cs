using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PatientPortalAPI.Core.Application.DTOs;
using PatientPortalAPI.Infrastructure.Security;
using Dapper;
using PatientPortalAPI.Infrastructure.Data;
using BCrypt.Net;

namespace PatientPortalAPI.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController(
    IJwtProvider jwtProvider, 
    IDbConnectionFactory dbConnectionFactory,
    IUnitOfWork unitOfWork) : ControllerBase
{
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        using var connection = dbConnectionFactory.CreateConnection();

        var user = await connection.QueryFirstOrDefaultAsync<dynamic>(@"
            SELECT u.UserID, u.Email, u.FirstName + ' ' + u.LastName AS FullName, u.TenantID, c.PasswordHash 
            FROM core.Users u
            INNER JOIN auth.Credential c ON u.UserID = c.UserID
            WHERE u.Email = @Email AND u.IsActive = 1",
            new { request.Email });

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
        // Automatic validation (FluentValidationAutoValidation) handles the rules now
        
        try
        {
            unitOfWork.BeginTransaction();

            var userId = Guid.NewGuid();
            var displayName = $"{request.FirstName} {request.LastName}";

            // 1. Insert into core.Users
            const string userSql = @"
                INSERT INTO core.Users 
                (UserID, TenantID, OrganizationID, Username, Email, DisplayName, FirstName, LastName, IsActive, CreatedAt, UpdatedAt)
                VALUES 
                (@UserID, @TenantID, @OrganizationID, @Username, @Email, @DisplayName, @FirstName, @LastName, 1, SYSDATETIMEOFFSET(), SYSDATETIMEOFFSET())";

            await unitOfWork.Connection.ExecuteAsync(userSql, new
            {
                UserID = userId,
                request.TenantID,
                request.OrganizationID,
                request.Username,
                request.Email,
                DisplayName = displayName,
                request.FirstName,
                request.LastName
            }, unitOfWork.Transaction);

            // 2. Insert into auth.Credential
            var passwordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);
            const string credentialSql = @"
                INSERT INTO auth.Credential 
                (CredentialID, UserID, PasswordHash, LastChangedAt, IsLocked, FailedAttempts)
                VALUES 
                (NEWID(), @UserID, @PasswordHash, SYSDATETIMEOFFSET(), 0, 0)";

            await unitOfWork.Connection.ExecuteAsync(credentialSql, new
            {
                UserID = userId,
                PasswordHash = passwordHash
            }, unitOfWork.Transaction);

            unitOfWork.Commit();

            return Ok(new { Message = "User registered successfully.", UserID = userId });
        }
        catch (Exception ex)
        {
            unitOfWork.Rollback();
            return BadRequest(new { Message = "Registration failed.", Error = ex.Message });
        }
    }
}
