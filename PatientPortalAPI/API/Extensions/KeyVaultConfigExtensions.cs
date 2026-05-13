using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using PatientPortalAPI.Core.Application.Constants;

namespace PatientPortalAPI.API.Extensions
{
    public class KeyVaultConfigExtensions
    {
        private readonly SecretClient _client;
        private readonly string _environment;

        public KeyVaultConfigExtensions(IConfiguration configuration)
        {
            _environment = configuration["environment:name"]!;

            var vaultName = configuration["AzureKeyVault:Vault"];
            var tenantId = configuration["AzureKeyVault:TenantId"];
            var clientId = configuration["AzureKeyVault:ClientId"];
            var clientSecret = configuration["AzureKeyVault:ClientSecret"];

            var credential = new ClientSecretCredential(tenantId, clientId, clientSecret);
            _client = new SecretClient(new Uri(vaultName!), credential);
        }

        public async Task<IDictionary<string, string>> LoadSecretsAsync()
        {
            var keys = new[]
            {
                Env(SecretKeys.SqlConnection),
                Env(SecretKeys.JwtIssuer),
                Env(SecretKeys.JwtSecret),
                Env(SecretKeys.JwtExpiresIn)
            };

            var secrets = new Dictionary<string, string>();

            foreach (var key in keys)
            {
                var value = (await _client.GetSecretAsync(key)).Value.Value;
                secrets[NormalizeKey(key)] = value;
            }

            return secrets;
        }

        private string Env(string key)
        {
            return $"{_environment}-{key}";
        }

        private string NormalizeKey(string key)
        {
            if (key.StartsWith($"{_environment}-"))
                return key.Replace($"{_environment}-", "");

            return key;
        }
    }
}
