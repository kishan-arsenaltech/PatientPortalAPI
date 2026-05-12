using FluentValidation;
using PatientPortalAPI.Core.Application.DTOs;
using PatientPortalAPI.Infrastructure.Data;
using Dapper;

namespace PatientPortalAPI.Core.Application.Validators;

public class RegisterValidator : AbstractValidator<RegisterRequest>
{
    private readonly IDbConnectionFactory _dbConnectionFactory;

    public RegisterValidator(IDbConnectionFactory dbConnectionFactory)
    {
        _dbConnectionFactory = dbConnectionFactory;

        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required.")
            .EmailAddress().WithMessage("Invalid email format.")
            .Must(BeUniqueEmail).WithMessage("This email is already registered.");

        RuleFor(x => x.Username)
            .NotEmpty().WithMessage("Username is required.")
            .MinimumLength(3).WithMessage("Username must be at least 3 characters.")
            .Must(BeUniqueUsername).WithMessage("This username is already taken.");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Password is required.")
            .MinimumLength(8).WithMessage("Password must be at least 8 characters.")
            .Matches(@"[A-Z]").WithMessage("Password must contain at least one uppercase letter.")
            .Matches(@"[a-z]").WithMessage("Password must contain at least one lowercase letter.")
            .Matches(@"[0-9]").WithMessage("Password must contain at least one number.")
            .Matches(@"[\!\?\*\.]").WithMessage("Password must contain at least one special character (!?*.).");

        RuleFor(x => x.FirstName)
            .NotEmpty().WithMessage("First name is required.");

        RuleFor(x => x.LastName)
            .NotEmpty().WithMessage("Last name is required.");
    }

    private bool BeUniqueEmail(string email)
    {
        using var connection = _dbConnectionFactory.CreateConnection();
        var count = connection.ExecuteScalar<int>(
            "SELECT COUNT(1) FROM core.Users WHERE Email = @Email AND DeletedAt IS NULL",
            new { Email = email });
        return count == 0;
    }

    private bool BeUniqueUsername(string username)
    {
        using var connection = _dbConnectionFactory.CreateConnection();
        var count = connection.ExecuteScalar<int>(
            "SELECT COUNT(1) FROM core.Users WHERE Username = @Username AND DeletedAt IS NULL",
            new { Username = username });
        return count == 0;
    }
}
