using Microsoft.EntityFrameworkCore;
using ExpenseGuard.Domain.Entities;
using ExpenseGuard.Domain.Interfaces;
using ExpenseGuard.Infrastructure.Persistence;

namespace ExpenseGuard.Infrastructure.Repositories;

// ── Receipt Repository ───────────────────────────────────────
public class ReceiptRepository : IReceiptRepository
{
    private readonly AppDbContext _db;

    public ReceiptRepository(AppDbContext db) => _db = db;

    public async Task<Receipt?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default)
        => await _db.Receipts
            .FirstOrDefaultAsync(r => r.Id == id && (tenantId == Guid.Empty || r.TenantId == tenantId), ct);

    public async Task<IReadOnlyList<Receipt>> GetByUserAsync(
        Guid userId, Guid tenantId, int page, int pageSize, CancellationToken ct = default)
        => await _db.Receipts
            .Where(r => r.SubmittedBy == userId && r.TenantId == tenantId)
            .OrderByDescending(r => r.SubmittedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

    public async Task<IReadOnlyList<Receipt>> GetByDepartmentAsync(
        Guid departmentId, Guid tenantId, int page, int pageSize, CancellationToken ct = default)
        => await _db.Receipts
            .Where(r => r.DepartmentId == departmentId && r.TenantId == tenantId)
            .OrderByDescending(r => r.SubmittedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

    public async Task<IReadOnlyList<Receipt>> GetAllForTenantAsync(
        Guid tenantId, int page, int pageSize, CancellationToken ct = default)
        => await _db.Receipts
            .Where(r => r.TenantId == tenantId)
            .OrderByDescending(r => r.SubmittedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

    public async Task<IReadOnlyList<Receipt>> GetHighRiskAsync(
        Guid tenantId, int minScore, CancellationToken ct = default)
        => await _db.Receipts
            .Where(r => r.TenantId == tenantId && r.FraudScore.HasValue && r.FraudScore >= minScore)
            .OrderByDescending(r => r.FraudScore)
            .ToListAsync(ct);

    public async Task AddAsync(Receipt receipt, CancellationToken ct = default)
    {
        await _db.Receipts.AddAsync(receipt, ct);
        await _db.SaveChangesAsync(ct);
    }

    public async Task UpdateAsync(Receipt receipt, CancellationToken ct = default)
    {
        _db.Receipts.Update(receipt);
        await _db.SaveChangesAsync(ct);
    }

    public async Task<decimal> GetMonthlySpendAsync(
        Guid departmentId, int year, int month, CancellationToken ct = default)
        => await _db.Receipts
            .Where(r => r.DepartmentId == departmentId
                     && r.ReceiptDate.Year  == year
                     && r.ReceiptDate.Month == month
                     && r.Status != Domain.Enums.ReceiptStatus.Rejected)
            .SumAsync(r => r.Amount, ct);

    public async Task<(int TotalCount, int ApprovedCount, int RejectedCount, int PendingCount, decimal TotalAmount)> GetStatsAsync(Guid tenantId, CancellationToken ct = default)
    {
        var query = _db.Receipts.Where(r => r.TenantId == tenantId);
        
        var total = await query.CountAsync(ct);
        var approved = await query.CountAsync(r => r.Status == Domain.Enums.ReceiptStatus.Approved, ct);
        var rejected = await query.CountAsync(r => r.Status == Domain.Enums.ReceiptStatus.Rejected, ct);
        var pending = await query.CountAsync(r => r.Status == Domain.Enums.ReceiptStatus.Pending || r.Status == Domain.Enums.ReceiptStatus.AiProcessing, ct);
        var amount = await query.Where(r => r.Status != Domain.Enums.ReceiptStatus.Rejected).SumAsync(r => r.Amount, ct);

        return (total, approved, rejected, pending, amount);
    }

    public async Task<IReadOnlyList<Receipt>> GetRecentActivityAsync(Guid tenantId, int count, CancellationToken ct = default)
    {
        return await _db.Receipts
            .Where(r => r.TenantId == tenantId)
            .OrderByDescending(r => r.SubmittedAt)
            .Take(count)
            .ToListAsync(ct);
    }

    public async Task<bool> IsDuplicateAsync(Guid tenantId, string vendorName, decimal amount, DateOnly receiptDate, Guid? excludeId = null, CancellationToken ct = default)
    {
        return await _db.Receipts.AnyAsync(r => 
            r.TenantId == tenantId &&
            r.VendorName.ToLower() == vendorName.ToLower() &&
            r.Amount == amount &&
            r.ReceiptDate == receiptDate &&
            (excludeId == null || r.Id != excludeId), ct);
    }
}

// ── User Repository ──────────────────────────────────────────
public class UserRepository : IUserRepository
{
    private readonly AppDbContext _db;

    public UserRepository(AppDbContext db) => _db = db;

    public async Task<User?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default)
        => await _db.Users.FirstOrDefaultAsync(
            u => u.Id == id && u.TenantId == tenantId, ct);

    public async Task<User?> GetByEmailAsync(string email, Guid tenantId, CancellationToken ct = default)
        => await _db.Users.FirstOrDefaultAsync(
            u => u.Email == email.ToLowerInvariant() && u.TenantId == tenantId, ct);

    public async Task AddAsync(User user, CancellationToken ct = default)
    {
        await _db.Users.AddAsync(user, ct);
        await _db.SaveChangesAsync(ct);
    }

    public async Task UpdateAsync(User user, CancellationToken ct = default)
    {
        _db.Users.Update(user);
        await _db.SaveChangesAsync(ct);
    }
}

// ── Budget Repository ────────────────────────────────────────
public class BudgetRepository : IBudgetRepository
{
    private readonly AppDbContext _db;

    public BudgetRepository(AppDbContext db) => _db = db;

    public async Task<BudgetLimit?> GetAsync(
        Guid departmentId, int year, int month, CancellationToken ct = default)
        => await _db.BudgetLimits.FirstOrDefaultAsync(
            b => b.DepartmentId == departmentId
              && b.PeriodYear  == year
              && b.PeriodMonth == month, ct);

    public async Task UpsertAsync(BudgetLimit budget, CancellationToken ct = default)
    {
        var existing = await GetAsync(budget.DepartmentId, budget.PeriodYear, budget.PeriodMonth, ct);
        if (existing is null)
            await _db.BudgetLimits.AddAsync(budget, ct);
        else
        {
            existing.LimitAmount = budget.LimitAmount;
            existing.Currency    = budget.Currency;
            _db.BudgetLimits.Update(existing);
        }
        await _db.SaveChangesAsync(ct);
    }

    public async Task<IReadOnlyList<BudgetLimit>> GetByDepartmentAsync(
        Guid departmentId, CancellationToken ct = default)
        => await _db.BudgetLimits
            .Where(b => b.DepartmentId == departmentId)
            .OrderByDescending(b => b.PeriodYear).ThenByDescending(b => b.PeriodMonth)
            .ToListAsync(ct);
}

// ── Department Repository ────────────────────────────────────
public class DepartmentRepository : IDepartmentRepository
{
    private readonly AppDbContext _db;
    public DepartmentRepository(AppDbContext db) => _db = db;
    
    public async Task<IReadOnlyList<Department>> GetAllForTenantAsync(Guid tenantId, CancellationToken ct = default)
        => await _db.Departments.Where(d => d.TenantId == tenantId).ToListAsync(ct);
}
