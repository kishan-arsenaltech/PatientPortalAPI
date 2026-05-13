namespace PatientPortalAPI.Core.Application.Settings
{
    public class JwtConfig
    {
        public string JwtIssuer { get; set; }
        public string JwtSecret { get; set; }
        public string JwtExpiresIn { get; set; }

        public JwtConfig(string secretJwtIssuerValue, string secretJwtSecretValue, string secretJwtExpiresIn)
        {
            JwtIssuer = secretJwtIssuerValue;
            JwtSecret = secretJwtSecretValue;
            JwtExpiresIn = secretJwtExpiresIn;
        }
    }
}
