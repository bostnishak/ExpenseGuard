using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using ExpenseGuard.Application.DTOs;
using ExpenseGuard.Application.Services;
using ExpenseGuard.Domain.Interfaces;
using ExpenseGuard.Domain.Entities;
using ExpenseGuard.Domain.Enums;

namespace ExpenseGuard.API.Controllers;

/// <summary>Admin panel — Tüm tenant verileri, kullanıcı yönetimi, bütçe ayarları.</summary>
[ApiController]
[Route("api/admin")]
[Authorize(Roles = "Admin")]
public class AdminController : ControllerBase
{
    private readonly IReceiptRepository _receipts;
    private readonly IUserRepository    _users;
    private readonly IBudgetRepository  _budgets;
    private readonly ReceiptService     _receiptService;

    public AdminController(
        IReceiptRepository receipts,
        IUserRepository    users,
        IBudgetRepository  budgets,
        ReceiptService     receiptService)
    {
        _receipts       = receipts;
        _users          = users;
        _budgets        = budgets;
        _receiptService = receiptService;
    }

    private Guid TenantId => Guid.Parse(User.FindFirstValue("tenant_id")!);

    // ── Tüm Fişler ──────────────────────────────────────────
    [HttpGet("receipts")]
    public async Task<IActionResult> GetAllReceipts(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken ct = default)
    {
        var result = await _receipts.GetAllForTenantAsync(TenantId, page, pageSize, ct);
        return Ok(new { items = result, totalCount = result.Count, page, pageSize });
    }

    // ── Yüksek Riskli Fişler ─────────────────────────────────
    [HttpGet("receipts/high-risk")]
    public async Task<IActionResult> GetHighRisk(
        [FromQuery] int minScore = 60,
        CancellationToken ct = default)
    {
        var result = await _receiptService.GetHighRiskAsync(TenantId, minScore, ct);
        return Ok(result);
    }

    // ── Bütçe Upsert ─────────────────────────────────────────
    [HttpPut("budgets")]
    public async Task<IActionResult> SetBudget(
        [FromBody] BudgetUpsertRequest req,
        CancellationToken ct = default)
    {
        var budget = new BudgetLimit
        {
            TenantId     = TenantId,
            DepartmentId = req.DepartmentId,
            PeriodYear   = (short)req.Year,
            PeriodMonth  = (short)req.Month,
            LimitAmount  = req.LimitAmount,
            Currency     = req.Currency,
            CreatedBy    = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!),
        };
        await _budgets.UpsertAsync(budget, ct);
        return Ok(new { message = "Bütçe limiti güncellendi", budget });
    }

    // ── Bütçe Sorgula ────────────────────────────────────────
    [HttpGet("budgets/{departmentId:guid}/{year:int}/{month:int}")]
    public async Task<IActionResult> GetBudget(
        Guid departmentId, int year, int month,
        CancellationToken ct = default)
    {
        var result = await _receiptService.GetBudgetStatusAsync(
            departmentId, TenantId, year, month, "Departman", ct);
        return result is null ? NotFound() : Ok(result);
    }

    // ── Dashboard Özeti ──────────────────────────────────────
    [HttpGet("dashboard")]
    [Authorize(Roles = "Admin,Finance,Manager")]
    public async Task<IActionResult> GetDashboard(CancellationToken ct = default)
    {
        var now        = DateTime.UtcNow;
        var allReceipts= await _receipts.GetAllForTenantAsync(TenantId, 1, 1000, ct);
        var highRisk   = await _receipts.GetHighRiskAsync(TenantId, 60, ct);

        var pending  = allReceipts.Count(r => r.Status == ReceiptStatus.Pending || r.Status == ReceiptStatus.AiProcessing);
        var approved = allReceipts.Count(r => r.Status == ReceiptStatus.Approved);
        var rejected = allReceipts.Count(r => r.Status == ReceiptStatus.Rejected);
        var flagged  = allReceipts.Count(r => r.Status == ReceiptStatus.Flagged);

        var thisMonthSpend = allReceipts
            .Where(r => r.ReceiptDate.Year  == now.Year
                     && r.ReceiptDate.Month == now.Month
                     && r.Status != ReceiptStatus.Rejected)
            .Sum(r => r.Amount);

        return Ok(new
        {
            summary = new
            {
                totalReceipts    = allReceipts.Count,
                pendingCount     = pending,
                approvedCount    = approved,
                rejectedCount    = rejected,
                flaggedCount     = flagged,
                highRiskCount    = highRisk.Count,
                thisMonthSpend   = thisMonthSpend,
            },
            recentHighRisk = highRisk.Take(5).Select(r => new
            {
                r.Id,
                r.FraudScore,
                r.RiskLevel,
                r.Amount,
                r.VendorName,
                r.ReceiptDate,
                r.Status,
            }),
        });
    }
}
