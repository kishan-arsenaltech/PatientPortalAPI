using PatientPortalAPI.API.Extensions;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.ConfigureLogging();

await builder.AddKeyVaultConfiguration();

builder.Services.AddPatientPortalApplication(
    builder.Environment,
    builder.Configuration
);

builder.Services.AddCors(options =>
{
    options.AddPolicy("CorsPolicy", policy =>
    {
        policy
            .AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

try
{
    Log.Information("Starting Patient Intake API...");
    app.UseInvestPipeline(app.Services.GetRequiredService<IServiceScopeFactory>());
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