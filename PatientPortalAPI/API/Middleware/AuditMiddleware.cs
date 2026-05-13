using System.Diagnostics;
using System.Security.Claims;
using PatientPortalAPI.Infrastructure.Data;
using Dapper;

namespace PatientPortalAPI.API.Middleware;

public class AuditMiddleware(RequestDelegate next, ILogger<AuditMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context, IDbConnectionFactory dbFactory)
    {
        var stopwatch = Stopwatch.StartNew();
        var requestPath = context.Request.Path;
        var method = context.Request.Method;
        
        // We capture the body or parameters if needed, but for HIPAA we must be careful not to log PII 
        // unless strictly necessary and encrypted. For now, we log the action metadata.

        await next(context);

        stopwatch.Stop();

        try
        {
            var userId = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            var tenantId = context.User.FindFirst("TenantId")?.Value ?? Guid.Empty.ToString(); // Default or from context

            using var connection = dbFactory.CreateConnection();
            
            const string sql = @"
                INSERT INTO audit.ActivityLog 
                (TenantID, UserID, EntityType, Action, Module, IpAddress, UserAgent, RequestPath, ResultCode, DurationMs, CreatedAt)
                VALUES 
                (@TenantID, @UserID, @EntityType, @Action, @Module, @IpAddress, @UserAgent, @RequestPath, @ResultCode, @DurationMs, SYSDATETIMEOFFSET())";

            await connection.ExecuteAsync(sql, new
            {
                TenantID = Guid.Parse(tenantId),
                UserID = userId != null ? Guid.Parse(userId) : (Guid?)null,
                EntityType = "API_REQUEST",
                Action = method,
                Module = "SYSTEM",
                IpAddress = context.Connection.RemoteIpAddress?.ToString(),
                UserAgent = context.Request.Headers["User-Agent"].ToString(),
                RequestPath = requestPath.ToString(),
                ResultCode = context.Response.StatusCode,
                DurationMs = (int)stopwatch.ElapsedMilliseconds
            });
        }
        catch (Exception ex)
        {
            // We don't want audit failure to break the main request, but we must log it.
            logger.LogError(ex, "Failed to record audit log.");
        }
    }
}
