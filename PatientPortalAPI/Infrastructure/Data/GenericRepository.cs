using System.Data;
using System.Reflection;
using Dapper;
using PatientPortalAPI.Core.Application.Interfaces;
using PatientPortalAPI.Core.Domain;
using System.ComponentModel.DataAnnotations.Schema;

namespace PatientPortalAPI.Infrastructure.Data;

public class GenericRepository<T>(IDbConnectionFactory connectionFactory) : IGenericRepository<T> where T : class
{
    protected readonly IDbConnectionFactory _connectionFactory = connectionFactory;

    private string TableName => typeof(T).GetCustomAttribute<TableAttribute>()?.Name ?? typeof(T).Name;
    private string SchemaName => typeof(T).GetCustomAttribute<TableAttribute>()?.Schema ?? "dbo";
    private string FullTableName => $"[{SchemaName}].[{TableName}]";

    public virtual async Task<T?> GetByIdAsync(Guid id)
    {
        using var connection = _connectionFactory.CreateConnection();
        var primaryKey = typeof(T).GetProperties().First(p => p.Name.EndsWith("ID")).Name;
        var sql = $"SELECT * FROM {FullTableName} WHERE {primaryKey} = @Id AND DeletedAt IS NULL";
        return await connection.QuerySingleOrDefaultAsync<T>(sql, new { Id = id });
    }

    public virtual async Task<IEnumerable<T>> GetAllAsync()
    {
        using var connection = _connectionFactory.CreateConnection();
        var sql = $"SELECT * FROM {FullTableName} WHERE DeletedAt IS NULL";
        return await connection.QueryAsync<T>(sql);
    }

    public virtual async Task<Guid> AddAsync(T entity)
    {
        using var connection = _connectionFactory.CreateConnection();
        var properties = GetProperties(entity);
        var columnNames = string.Join(", ", properties.Select(p => $"[{p}]"));
        var parameterNames = string.Join(", ", properties.Select(p => $"@{p}"));
        
        var primaryKey = typeof(T).GetProperties().First(p => p.Name.EndsWith("ID")).Name;
        
        var sql = $"INSERT INTO {FullTableName} ({columnNames}) OUTPUT INSERTED.{primaryKey} VALUES ({parameterNames})";
        
        return await connection.ExecuteScalarAsync<Guid>(sql, entity);
    }

    public virtual async Task<bool> UpdateAsync(T entity)
    {
        using var connection = _connectionFactory.CreateConnection();
        var properties = GetProperties(entity);
        var primaryKey = typeof(T).GetProperties().First(p => p.Name.EndsWith("ID")).Name;
        
        var setClause = string.Join(", ", properties.Where(p => p != primaryKey).Select(p => $"[{p}] = @{p}"));
        
        var sql = $"UPDATE {FullTableName} SET {setClause}, UpdatedAt = SYSDATETIMEOFFSET() WHERE {primaryKey} = @{primaryKey}";
        
        var result = await connection.ExecuteAsync(sql, entity);
        return result > 0;
    }

    public virtual async Task<bool> DeleteAsync(Guid id)
    {
        using var connection = _connectionFactory.CreateConnection();
        var primaryKey = typeof(T).GetProperties().First(p => p.Name.EndsWith("ID")).Name;
        var sql = $"UPDATE {FullTableName} SET DeletedAt = SYSDATETIMEOFFSET(), IsActive = 0 WHERE {primaryKey} = @Id";
        var result = await connection.ExecuteAsync(sql, new { Id = id });
        return result > 0;
    }

    public virtual async Task<IEnumerable<T>> GetPagedAsync(int page, int pageSize, string? filter = null)
    {
        using var connection = _connectionFactory.CreateConnection();
        var offset = (page - 1) * pageSize;
        var primaryKey = typeof(T).GetProperties().First(p => p.Name.EndsWith("ID")).Name;
        
        var sql = $@"
            SELECT * FROM {FullTableName} 
            WHERE DeletedAt IS NULL 
            {(string.IsNullOrEmpty(filter) ? "" : $" AND {filter}")}
            ORDER BY {primaryKey} 
            OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY";

        return await connection.QueryAsync<T>(sql, new { Offset = offset, PageSize = pageSize });
    }

    private IEnumerable<string> GetProperties(T entity)
    {
        return typeof(T).GetProperties()
            .Where(p => p.Name != "RowVersion" && p.GetCustomAttribute<NotMappedAttribute>() == null)
            .Select(p => p.Name);
    }
}
