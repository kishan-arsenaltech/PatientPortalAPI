namespace PatientPortalAPI.Core.Application.Settings
{
    public class AppSecrets
    {
        public bool IsDevelopment { get; set; } = false;
        public bool IsProduction { get; set; } = false;

        public string SqlConnection { get; set; } = default!;

        public string JwtIssuer { get; set; } = default!;
        public string JwtSecret { get; set; } = default!;
        public int JwtExpiresIn { get; set; }
    }
}
