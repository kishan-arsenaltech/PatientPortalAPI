namespace PatientPortalAPI.Infrastructure.Security;

public interface IEncryptionService
{
    string Encrypt(string plainText);
    string Decrypt(string cipherText);
}
