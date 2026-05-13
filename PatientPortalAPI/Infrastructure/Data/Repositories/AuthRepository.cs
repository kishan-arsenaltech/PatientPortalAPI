using Dapper;
using PatientPortalAPI.Core.Application.DTOs;
using PatientPortalAPI.Core.Application.Interfaces;

namespace PatientPortalAPI.Infrastructure.Data.Repositories;

public class AuthRepository(IDbConnectionFactory dbConnectionFactory, IUnitOfWork unitOfWork) : IAuthRepository
{
    public async Task<dynamic?> GetUserWithCredentialByEmailAsync(string email)
    {
        using var connection = dbConnectionFactory.CreateConnection();
        return await connection.QueryFirstOrDefaultAsync<dynamic>(@"
            SELECT u.UserID, u.Email, u.FirstName + ' ' + u.LastName AS FullName, u.TenantID, c.PasswordHash 
            FROM core.Users u
            INNER JOIN auth.Credential c ON u.UserID = c.UserID
            WHERE u.Email = @Email AND u.IsActive = 1",
            new { Email = email });
    }

    public async Task<Guid> RegisterUserAsync(RegisterRequest request, string passwordHash)
    {
        try
        {
            unitOfWork.BeginTransaction();

            var userId = Guid.NewGuid();
            var displayName = $"{request.FirstName} {request.LastName}";

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
            return userId;
        }
        catch
        {
            unitOfWork.Rollback();
            throw;
        }
    }
}
