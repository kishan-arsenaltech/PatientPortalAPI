namespace PatientPortalAPI.Core.Application.Interfaces;

public interface IGenericRepository<T> where T : class
{
    Task<T?> GetByIdAsync(Guid id);
    Task<IEnumerable<T>> GetAllAsync();
    Task<Guid> AddAsync(T entity);
    Task<bool> UpdateAsync(T entity);
    Task<bool> DeleteAsync(Guid id);
    Task<IEnumerable<T>> GetPagedAsync(int page, int pageSize, string? filter = null);
}
