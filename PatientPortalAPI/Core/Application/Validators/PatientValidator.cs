using FluentValidation;
using PatientPortalAPI.Core.Domain;

namespace PatientPortalAPI.Core.Application.Validators;

public class PatientValidator : AbstractValidator<Patient>
{
    public PatientValidator()
    {
        RuleFor(p => p.FirstName)
            .NotEmpty().WithMessage("First name is required.")
            .MaximumLength(100);

        RuleFor(p => p.LastName)
            .NotEmpty().WithMessage("Last name is required.")
            .MaximumLength(100);

        RuleFor(p => p.Email)
            .EmailAddress().When(p => !string.IsNullOrEmpty(p.Email))
            .WithMessage("A valid email address is required.");

        RuleFor(p => p.DateOfBirth)
            .NotEmpty()
            .LessThan(DateTime.Today).WithMessage("Date of birth cannot be in the future.");

        RuleFor(p => p.GenderCode)
            .NotEmpty().WithMessage("Gender is required.")
            .MaximumLength(10);

        RuleFor(p => p.ZipCode)
            .Matches(@"^\d{5}(-\d{4})?$").When(p => !string.IsNullOrEmpty(p.ZipCode))
            .WithMessage("Invalid Zip Code format.");

        RuleFor(p => p.PhoneMobile)
            .Matches(@"^\+?[1-9]\d{1,14}$").When(p => !string.IsNullOrEmpty(p.PhoneMobile))
            .WithMessage("Invalid mobile phone format.");
            
        RuleFor(p => p.SSNEncrypted)
            .Length(9).When(p => !string.IsNullOrEmpty(p.SSNEncrypted))
            .WithMessage("SSN must be exactly 9 digits before encryption.");
    }
}
