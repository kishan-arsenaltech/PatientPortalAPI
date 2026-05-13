using Microsoft.OpenApi.Models;
using FluentValidation;
using FluentValidation.AspNetCore;
using PatientPortalAPI.Core.Application.Interfaces;
using PatientPortalAPI.Core.Application.Validators;
using PatientPortalAPI.Infrastructure.Data;
using PatientPortalAPI.Infrastructure.Data.Repositories;
using PatientPortalAPI.Infrastructure.Security;
using Serilog;

namespace PatientPortalAPI.API.Extensions;

public static class ServiceExtensions
{
    public static void ConfigureInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddSingleton<IDbConnectionFactory, SqlConnectionFactory>();
        services.AddScoped<IUnitOfWork, UnitOfWork>();
        
        // Repositories
        services.AddScoped(typeof(IGenericRepository<>), typeof(GenericRepository<>));
        services.AddScoped<IPatientRepository, PatientRepository>();
        services.AddScoped<IProviderRepository, ProviderRepository>();
        services.AddScoped<IOrderRepository, OrderRepository>();
        services.AddScoped<IReferralRepository, ReferralRepository>();
        services.AddScoped<IAuthRepository, AuthRepository>();

        // Security
        services.AddScoped<IEncryptionService, EncryptionService>();
        services.AddScoped<IJwtProvider, JwtProvider>();
    }

    public static void ConfigureValidation(this IServiceCollection services)
    {
        services.AddFluentValidationAutoValidation();
        services.AddValidatorsFromAssemblyContaining<PatientValidator>();
    }

    public static void ConfigureSwagger(this IServiceCollection services)
    {
        services.AddSwaggerGen(options =>
        {
            options.SwaggerDoc("v1", new OpenApiInfo
            {
                Title = "Patient Intake Enterprise API",
                Version = "v1",
                Description = "A production-ready healthcare API built with .NET 9 and Dapper."
            });

            options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
            {
                Name = "Authorization",
                Type = SecuritySchemeType.Http,
                Scheme = "bearer",
                BearerFormat = "JWT",
                In = ParameterLocation.Header,
                Description = "Enter your JWT token."
            });

            options.AddSecurityRequirement(new OpenApiSecurityRequirement
            {
                {
                    new OpenApiSecurityScheme
                    {
                        Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
                    },
                    Array.Empty<string>()
                }
            });
        });
    }

    public static void ConfigureHealthChecks(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddHealthChecks()
            .AddSqlServer(
                connectionString: configuration.GetConnectionString("DefaultConnection")!,
                name: "SQL Server",
                tags: new[] { "db", "sql", "sqlserver" });
    }

    public static void ConfigureLogging(this IHostBuilder host)
    {
        host.UseSerilog((context, loggerConfiguration) =>
        {
            loggerConfiguration.ReadFrom.Configuration(context.Configuration);
        });
    }
}
