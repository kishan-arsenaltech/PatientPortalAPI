using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using PatientPortalAPI.Core.Application.Constants;
using Serilog;

namespace PatientPortalAPI.API.Extensions
{
    public class KeyVaultConfigExtensions
    {
        private readonly SecretClient _client;
        private readonly string _environment;

        public KeyVaultConfigExtensions(IConfiguration configuration)
        {
            _environment = configuration["environment:name"] ?? "dev";

            var vaultName = configuration["AzureKeyVault:Vault"];
            var tenantId = configuration["AzureKeyVault:TenantId"];
            var clientId = configuration["AzureKeyVault:ClientId"];
            var clientSecret = configuration["AzureKeyVault:ClientSecret"];

            if (!string.IsNullOrEmpty(vaultName) && !string.IsNullOrEmpty(tenantId) && 
                !string.IsNullOrEmpty(clientId) && !string.IsNullOrEmpty(clientSecret))
            {
                var credential = new ClientSecretCredential(tenantId, clientId, clientSecret);
                _client = new SecretClient(new Uri($"https://{vaultName}"), credential);
            }
        }

        public async Task<IDictionary<string, string>?> LoadSecretsAsync()
        {
            if (_client == null) return null;

            try 
            {
                var keys = new[]
                {
                    Env(SecretKeys.SqlConnection),
                    Env(SecretKeys.JwtIssuer),
                    Env(SecretKeys.JwtSecret),
                    Env(SecretKeys.JwtExpiresIn),
                    Env(SecretKeys.EncryptionKey)
                };

                var secrets = new Dictionary<string, string>();

                foreach (var key in keys)
                {
                    var response = await _client.GetSecretAsync(key);
                    secrets[NormalizeKey(key)] = response.Value.Value;
                }

                return secrets;
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Failed to load secrets from Azure Key Vault. Falling back to local configuration.");
                return null;
            }
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
