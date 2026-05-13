using PatientPortalAPI.API.Extensions;
using PatientPortalAPI.API.Middleware;
using Serilog;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;

var builder = WebApplication.CreateBuilder(args);

// Configure Serilog
builder.Host.ConfigureLogging();

// Add services to the container
builder.Services.AddControllers();

// Swagger
builder.Services.ConfigureSwagger();

// Validation
builder.Services.ConfigureValidation();

// Infrastructure & Security
builder.Services.ConfigureInfrastructure(builder.Configuration);

// Health Checks
builder.Services.ConfigureHealthChecks(builder.Configuration);

// Auth
builder.Services.AddAuthentication().AddJwtBearer();
builder.Services.AddAuthorization();

var app = builder.Build();

// Middleware Pipeline
app.UseMiddleware<ExceptionHandlingMiddleware>();

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

// HIPAA Audit Middleware
app.UseMiddleware<AuditMiddleware>();

app.UseAuthentication();
app.UseAuthorization();

// Map Health Checks
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

try
{
    Log.Information("Starting Patient Intake API...");
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Host terminated unexpectedly.");
}
finally
{
    Log.CloseAndFlush();
}