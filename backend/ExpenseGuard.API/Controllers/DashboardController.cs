using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using ExpenseGuard.Application.Services;

namespace ExpenseGuard.API.Controllers;

[ApiController]
[Route("api/dashboard")]
[Authorize]
public class DashboardController : ControllerBase
{
    private readonly AnalyticsService _analytics;

    public DashboardController(AnalyticsService analytics)
    {
        _analytics = analytics;
    }

    private Guid TenantId => Guid.Parse(User.FindFirstValue("tenant_id")!);

    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary(CancellationToken ct)
    {
        var result = await _analytics.GetDashboardSummaryAsync(TenantId, ct);
        return Ok(result);
    }

    [HttpGet("recent-activity")]
    public async Task<IActionResult> GetRecentActivity([FromQuery] int count = 10, CancellationToken ct = default)
    {
        var result = await _analytics.GetRecentActivityAsync(TenantId, count, ct);
        return Ok(result);
    }

    [HttpGet("analytics")]
    public async Task<IActionResult> GetDetailedAnalytics(CancellationToken ct = default)
    {
        var result = await _analytics.GetDetailedAnalyticsAsync(TenantId, ct);
        return Ok(result);
    }
}
