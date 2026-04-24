using ExpenseGuard.Domain.Interfaces;

using Microsoft.EntityFrameworkCore;
using ExpenseGuard.Infrastructure.Persistence;

namespace ExpenseGuard.Application.Services;

public class AnalyticsService
{
    private readonly IReceiptRepository _receipts;
    private readonly AppDbContext _db;

    public AnalyticsService(IReceiptRepository receipts, AppDbContext db)
    {
        _receipts = receipts;
        _db = db;
    }

    public async Task<object> GetDashboardSummaryAsync(Guid tenantId, CancellationToken ct = default)
    {
        var stats = await _receipts.GetStatsAsync(tenantId, ct);
        return new
        {
            TotalReceipts = stats.TotalCount,
            ApprovedReceipts = stats.ApprovedCount,
            RejectedReceipts = stats.RejectedCount,
            PendingReceipts = stats.PendingCount,
            TotalAmount = stats.TotalAmount
        };
    }

    public async Task<object> GetRecentActivityAsync(Guid tenantId, int count, CancellationToken ct = default)
    {
        var recent = await _receipts.GetRecentActivityAsync(tenantId, count, ct);
        return recent.Select(r => new
        {
            r.Id,
            r.VendorName,
            r.Amount,
            Status = r.Status.ToString(),
            r.SubmittedAt,
            RiskLevel = r.RiskLevel.ToString(),
            r.Category
        }).ToList();
    }

    public async Task<object> GetDetailedAnalyticsAsync(Guid tenantId, CancellationToken ct = default)
    {
        var receipts = await _db.Receipts
            .Where(r => r.TenantId == tenantId && r.Status != ExpenseGuard.Domain.Enums.ReceiptStatus.Rejected)
            .ToListAsync(ct);

        var riskDistribution = receipts
            .GroupBy(r =>
            {
                if (!r.FraudScore.HasValue) return "0-10";
                var score = r.FraudScore.Value;
                if (score < 10) return "0-10";
                if (score < 20) return "10-20";
                if (score < 30) return "20-30";
                if (score < 50) return "30-50";
                if (score < 70) return "50-70";
                return "70-100";
            })
            .Select(g => new { Range = g.Key, Count = g.Count() })
            .ToDictionary(k => k.Range, v => v.Count);

        var categoryDistribution = receipts
            .GroupBy(r => string.IsNullOrEmpty(r.Category) ? "other" : r.Category.ToLower())
            .Select(g => new { Category = g.Key, Amount = g.Sum(x => x.Amount) })
            .ToDictionary(k => k.Category, v => v.Amount);

        return new
        {
            RiskDistribution = riskDistribution,
            CategoryDistribution = categoryDistribution
        };
    }
}
