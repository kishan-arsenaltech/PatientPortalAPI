using FluentValidation;
using PatientPortalAPI.Core.Domain;

namespace PatientPortalAPI.Core.Application.Validators;

public class OrderValidator : AbstractValidator<Order>
{
    public OrderValidator()
    {
        RuleFor(o => o.PatientID)
            .NotEmpty().WithMessage("Patient ID is required.");

        RuleFor(o => o.OrderDate)
            .NotEmpty()
            .LessThanOrEqualTo(DateTime.UtcNow).WithMessage("Order date cannot be in the future.");

        RuleFor(o => o.IcdCodes)
            .NotEmpty().WithMessage("ICD Diagnosis codes are required.");

        RuleFor(o => o.OrderType)
            .NotEmpty().WithMessage("Order type is required.");

        RuleFor(o => o.OrderStatus)
            .NotEmpty().WithMessage("Order status is required.");
    }
}
