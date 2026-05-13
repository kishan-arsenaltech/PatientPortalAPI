using Microsoft.Data.SqlClient;
using PatientPortalAPI.Data;
using PatientPortalAPI.Models;
using PatientPortalAPI.Repository.Interfaces;
using System.Data;

namespace PatientPortalAPI.Repository
{
    public class AuthRepository : IAuthRepository
    {
        private readonly DbHelper _dbHelper;

        public AuthRepository(DbHelper dbHelper)
        {
            _dbHelper = dbHelper;
        }

        public async Task<UserModel?> LoginAsync(LoginRequest request)
        {
            using SqlConnection connection = _dbHelper.GetConnection();

            using SqlCommand command = new SqlCommand(
                "sp_LoginUser",
                connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.AddWithValue("@UserName", request.UserName);
            command.Parameters.AddWithValue("@Password", request.Password);

            await connection.OpenAsync();

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                return new UserModel
                {
                    UserId = Convert.ToInt32(reader["Id"]),
                    UserName = reader["Username"].ToString()!,
                    RoleName = reader["RoleName"].ToString()!
                };
            }

            return null;
        }
    }
}
