using ExpenseGuard.Domain.Entities;

namespace ExpenseGuard.Domain.Interfaces;

// ── Repository Interfaces (Dependency Inversion) ─────────────

public interface IReceiptRepository
{
    Task<Receipt?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default);
    Task<IReadOnlyList<Receipt>> GetByUserAsync(Guid userId, Guid tenantId, int page, int pageSize, CancellationToken ct = default);
    Task<IReadOnlyList<Receipt>> GetByDepartmentAsync(Guid departmentId, Guid tenantId, int page, int pageSize, CancellationToken ct = default);
    Task<IReadOnlyList<Receipt>> GetAllForTenantAsync(Guid tenantId, int page, int pageSize, CancellationToken ct = default);
    Task<IReadOnlyList<Receipt>> GetHighRiskAsync(Guid tenantId, int minScore, CancellationToken ct = default);
    Task AddAsync(Receipt receipt, CancellationToken ct = default);
    Task UpdateAsync(Receipt receipt, CancellationToken ct = default);
    Task<decimal> GetMonthlySpendAsync(Guid departmentId, int year, int month, CancellationToken ct = default);
    Task<(int TotalCount, int ApprovedCount, int RejectedCount, int PendingCount, decimal TotalAmount)> GetStatsAsync(Guid tenantId, CancellationToken ct = default);
    Task<IReadOnlyList<Receipt>> GetRecentActivityAsync(Guid tenantId, int count, CancellationToken ct = default);
    Task<bool> IsDuplicateAsync(Guid tenantId, string vendorName, decimal amount, DateOnly receiptDate, Guid? excludeId = null, CancellationToken ct = default);
}

public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default);
    Task<User?> GetByEmailAsync(string email, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(User user, CancellationToken ct = default);
    Task UpdateAsync(User user, CancellationToken ct = default);
}

public interface IBudgetRepository
{
    Task<BudgetLimit?> GetAsync(Guid departmentId, int year, int month, CancellationToken ct = default);
    Task UpsertAsync(BudgetLimit budget, CancellationToken ct = default);
    Task<IReadOnlyList<BudgetLimit>> GetByDepartmentAsync(Guid departmentId, CancellationToken ct = default);
}

public interface IDepartmentRepository
{
    Task<IReadOnlyList<Department>> GetAllForTenantAsync(Guid tenantId, CancellationToken ct = default);
}

// ── Service Interfaces ────────────────────────────────────────

public interface ICacheService
{
    Task<T?> GetAsync<T>(string key, CancellationToken ct = default) where T : class;
    Task SetAsync<T>(string key, T value, TimeSpan? expiry = null, CancellationToken ct = default) where T : class;
    Task RemoveAsync(string key, CancellationToken ct = default);
}

public interface IMessagePublisher
{
    Task PublishAsync<T>(string queueName, T message, CancellationToken ct = default) where T : class;
}

public interface IEncryptionService
{
    string Encrypt(string plainText);
    string Decrypt(string cipherText);
    byte[] EncryptBytes(decimal value);
    decimal DecryptToDecimal(byte[] data);
}
