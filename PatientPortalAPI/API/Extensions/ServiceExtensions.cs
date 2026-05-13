using FluentValidation;
using FluentValidation.AspNetCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using PatientPortalAPI.API.Middleware;
using PatientPortalAPI.Core.Application.Constants;
using PatientPortalAPI.Core.Application.Interfaces;
using PatientPortalAPI.Core.Application.Settings;
using PatientPortalAPI.Core.Application.Validators;
using PatientPortalAPI.Infrastructure.Data;
using PatientPortalAPI.Infrastructure.Data.Repositories;
using PatientPortalAPI.Infrastructure.Security;
using Serilog;
using System.Text;

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

        var jwtConfig = new JwtConfig(
            configuration[SecretKeys.JwtIssuer]!,
            configuration[SecretKeys.JwtSecret]!,
            configuration[SecretKeys.JwtExpiresIn]!);

        services.AddSingleton(jwtConfig);

        // Security
        services.AddScoped<IEncryptionService, EncryptionService>();
        services.AddScoped<IJwtProvider, JwtProvider>();
    }

    public static void ConfigureValidation(this IServiceCollection services)
    {
        services.AddFluentValidationAutoValidation();
        services.AddValidatorsFromAssemblyContaining<PatientValidator>();
    }

    public static async Task AddKeyVaultConfiguration(this WebApplicationBuilder builder)
    {
        var keyVault = new KeyVaultConfigExtensions(builder.Configuration);
        var secrets = await keyVault.LoadSecretsAsync();
        builder.Configuration.AddInMemoryCollection(secrets!);
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
                connectionString: configuration[SecretKeys.SqlConnection]!,
                name: "SQL Server",
                tags: ["db", "sql", "sqlserver"]);
    }

    public static void AddJwtAuth(this IServiceCollection services, IConfiguration config)
    {
        string jwtIssuer = config[SecretKeys.JwtIssuer]!;
        string jwtSecret = config[SecretKeys.JwtSecret]!;

        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret));

        services.AddAuthentication(options =>
        {
            options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
            options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
        })
        .AddJwtBearer(options =>
        {
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer = jwtIssuer,
                ValidAudience = jwtIssuer,
                IssuerSigningKey = signingKey
            };
        });
    }

    public static void ConfigureLogging(this IHostBuilder host)
    {
        host.UseSerilog((context, loggerConfiguration) =>
        {
            loggerConfiguration.ReadFrom.Configuration(context.Configuration);
        });
    }

    public static void AddHttpClients(this IServiceCollection services)
    {
        services.AddHttpClient();
    }

    public static void AddCaching(this IServiceCollection services)
    {
        services.AddResponseCaching();
    }

    public static void AddControllerServices(this IServiceCollection services)
    {
        services.AddControllers(options =>
        {
            options.CacheProfiles.Add("30SecondsCaching", new CacheProfile { Duration = 30 });
        });

        services.AddEndpointsApiExplorer();
    }

    public static void AddPatientPortalApplication(this IServiceCollection services, IWebHostEnvironment environment, IConfiguration configuration)
    {
        services.AddSingleton<AppSecrets>(sp =>
        {
            var config = sp.GetRequiredService<IConfiguration>();

            return new AppSecrets
            {
                IsDevelopment = environment.IsDevelopment(),
                IsProduction = environment.IsProduction(),
                SqlConnection = config[SecretKeys.SqlConnection]!,
                JwtIssuer = config[SecretKeys.JwtIssuer]!,
                JwtSecret = config[SecretKeys.JwtSecret]!,
                JwtExpiresIn = int.Parse(config[SecretKeys.JwtExpiresIn]!)
            };
        });

        services.AddHttpClients();
        services.AddCaching();
        services.ConfigureHealthChecks(configuration);
        services.AddJwtAuth(configuration);
        services.AddAuthorization();
        services.AddControllerServices();
        services.ConfigureSwagger();
        services.ConfigureValidation();
        services.ConfigureInfrastructure(configuration);
    }

    public static void UseInvestPipeline(this WebApplication app, IServiceScopeFactory scopeFactory)
    {
        if (app.Environment.IsDevelopment())
        {
            app.UseSwagger();
            app.UseSwaggerUI(c =>
            {
                c.SwaggerEndpoint("/swagger/v1/swagger.json", "Patient Intake API v1");
                c.RoutePrefix = "swagger"; // Swagger will be at /swagger
            });
        }

        app.UseHttpsRedirection();
        app.UseCors("CorsPolicy");
        app.UseResponseCaching();

        app.UseMiddleware<ExceptionHandlingMiddleware>();
        app.UseMiddleware<AuditMiddleware>();

        app.UseAuthentication();
        app.UseAuthorization();

        app.MapHealthChecks("/health", new HealthCheckOptions
        {
            Predicate = _ => true,
            ResponseWriter = async (context, report) =>
            {
                context.Response.ContentType = "application/json";
                var result = System.Text.Json.JsonSerializer.Serialize(new
                {
                    status = report.Status.ToString(),
                    checks = report.Entries.Select(e => new
                    {
                        check = e.Key,
                        status = e.Value.Status.ToString()
                    })
                });
                await context.Response.WriteAsync(result);
            }
        });

        app.MapControllers();
    }
}
