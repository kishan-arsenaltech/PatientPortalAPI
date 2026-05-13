namespace PatientPortalAPI.Models
{
    public class UserModel
    {
        public int UserId { get; set; }

        public string UserName { get; set; } = string.Empty;

        public string Password { get; set; } = string.Empty;

        public string RoleName { get; set; } = string.Empty;
    }
}
