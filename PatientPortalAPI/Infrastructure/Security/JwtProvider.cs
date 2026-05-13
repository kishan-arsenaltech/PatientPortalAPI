using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using PatientPortalAPI.Core.Application.Settings;

namespace PatientPortalAPI.Infrastructure.Security;

public class JwtProvider : IJwtProvider
{
    private readonly JwtConfig _jwtConfig;

    public JwtProvider(IConfiguration configuration)
    {
        _jwtConfig = configuration.GetSection("JwtConfig").Get<JwtConfig>() ?? throw new Exception("JwtConfig is missing");
    }

    public string GenerateToken(Guid userId, string email, Guid tenantId, IEnumerable<string> roles)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, userId.ToString()),
            new(JwtRegisteredClaimNames.Email, email),
            new("TenantId", tenantId.ToString())
        };

        foreach (var role in roles)
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtConfig.JwtSecret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _jwtConfig.JwtIssuer,
            audience: _jwtConfig.JwtIssuer,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(double.Parse(_jwtConfig.JwtExpiresIn)),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
