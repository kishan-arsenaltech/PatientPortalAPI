namespace PatientPortalAPI.Core.Application.DTOs;

public record LoginRequest(string Email, string Password);
public record LoginResponse(string Token, string Email, string FullName);

public record RegisterRequest(
    Guid TenantID,
    Guid? OrganizationID,
    string Username,
    string Email,
    string FirstName,
    string LastName,
    string Password
);
