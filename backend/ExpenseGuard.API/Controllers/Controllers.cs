using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using ExpenseGuard.Application.DTOs;
using ExpenseGuard.Application.Services;
using ExpenseGuard.Infrastructure.Security;

namespace ExpenseGuard.API.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly AuthService _auth;

    public AuthController(AuthService auth) => _auth = auth;

    /// <summary>Kullanıcı girişi — JWT access token + Refresh Token döner.</summary>
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login(
        [FromBody] LoginRequest req,
        [FromHeader(Name = "X-Tenant-Domain")] string tenantDomain,
        CancellationToken ct)
    {
        if (!HttpContext.Items.TryGetValue("TenantId", out var tenantIdObj))
            return Unauthorized(new { error = "Geçersiz tenant" });

        var tenantId = (Guid)tenantIdObj!;
        var ip       = HttpContext.Connection.RemoteIpAddress?.ToString();
        var result   = await _auth.LoginAsync(req, tenantId, ip, ct);

        if (result is null)
            return Unauthorized(new { error = "E-posta veya şifre hatalı" });

        return Ok(result);
    }

    /// <summary>Refresh Token ile yeni access token al (Token Rotation).</summary>
    [HttpPost("refresh")]
    [AllowAnonymous]
    public async Task<IActionResult> Refresh(
        [FromBody] RefreshTokenRequest req,
        CancellationToken ct)
    {
        var ip     = HttpContext.Connection.RemoteIpAddress?.ToString();
        var result = await _auth.RefreshAsync(req.RefreshToken, ip, ct);

        if (result is null)
            return Unauthorized(new { error = "Geçersiz veya süresi dolmuş refresh token" });

        return Ok(result);
    }

    /// <summary>Bu cihazdan çıkış (tek token iptal).</summary>
    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout(
        [FromBody] RefreshTokenRequest req,
        CancellationToken ct)
    {
        await _auth.LogoutAsync(req.RefreshToken, ct);
        return Ok(new { message = "Başarıyla çıkış yapıldı" });
    }

    /// <summary>Tüm cihazlardan çıkış (tüm token'lar iptal).</summary>
    [HttpPost("logout-all")]
    [Authorize]
    public async Task<IActionResult> LogoutAll(CancellationToken ct)
    {
        var userId   = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var tenantId = Guid.Parse(User.FindFirstValue("tenant_id")!);
        await _auth.LogoutAllAsync(userId, tenantId, ct);
        return Ok(new { message = "Tüm cihazlardan çıkış yapıldı" });
    }

    [HttpGet("me")]
    [Authorize]
    public IActionResult Me()
    {
        return Ok(new
        {
            id           = User.FindFirstValue(ClaimTypes.NameIdentifier),
            email        = User.FindFirstValue(ClaimTypes.Email),
            role         = User.FindFirstValue("role"),
            tenantId     = User.FindFirstValue("tenant_id"),
            departmentId = User.FindFirstValue("department_id"),
        });
    }

    [HttpPost("forgot-password")]
    [AllowAnonymous]
    public async Task<IActionResult> ForgotPassword(
        [FromBody] ForgotPasswordRequest req,
        CancellationToken ct)
    {
        if (!HttpContext.Items.TryGetValue("TenantId", out var tenantIdObj))
            return BadRequest(new { error = "Geçersiz tenant" });

        var tenantId = (Guid)tenantIdObj!;
        
        // Güvenlik gereği her zaman başarılı dönüyoruz (Kullanıcı olup olmamasını ifşa etmemek için)
        await _auth.ForgotPasswordAsync(req.Email, tenantId, ct);
        
        return Ok(new { message = "Şifre sıfırlama linki e-posta adresinize gönderildi (Eğer kayıtlıysa)." });
    }

    [HttpPost("reset-password")]
    [AllowAnonymous]
    public async Task<IActionResult> ResetPassword(
        [FromBody] ResetPasswordRequest req,
        CancellationToken ct)
    {
        if (!HttpContext.Items.TryGetValue("TenantId", out var tenantIdObj))
            return BadRequest(new { error = "Geçersiz tenant" });

        var tenantId = (Guid)tenantIdObj!;
        var success = await _auth.ResetPasswordAsync(req.Token, req.NewPassword, tenantId, ct);

        if (!success)
            return BadRequest(new { error = "Token geçersiz veya süresi dolmuş." });

        return Ok(new { message = "Şifreniz başarıyla sıfırlandı." });
    }
}

public record ForgotPasswordRequest(string Email);
public record ResetPasswordRequest(string Token, string NewPassword);

// ──────────────────────────────────────────────────────────────
[ApiController]
[Route("api/receipts")]
[Authorize]
public class ReceiptsController : ControllerBase
{
    private readonly ReceiptService _service;
    private readonly IConfiguration _config;

    public ReceiptsController(ReceiptService service, IConfiguration config)
    {
        _service = service;
        _config  = config;
    }

    private Guid TenantId   => Guid.Parse(User.FindFirstValue("tenant_id")!);
    private Guid UserId     => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private Guid DeptId     => Guid.TryParse(User.FindFirstValue("department_id"), out var g) ? g : Guid.Empty;
    private string UserRole => User.FindFirstValue("role") ?? "employee";
    private string CallbackBase => _config["Api:BaseUrl"] ?? "http://api:8080";

    /// <summary>Yeni fiş yükle — AI analizi asenkron başlar.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateReceiptRequest req, CancellationToken ct)
    {
        if (DeptId == Guid.Empty)
            return BadRequest(new { error = "Kullanıcının departmanı tanımlı değil" });

        var result = await _service.CreateAsync(req, TenantId, UserId, DeptId, CallbackBase, ct);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken ct)
    {
        try 
        {
            var receipt = await _service.GetReceiptDetailAsync(id, TenantId, UserId, UserRole.ToLowerInvariant(), DeptId, ct);
            return Ok(receipt);
        }
        catch (UnauthorizedAccessException) 
        {
            return Forbid();
        }
        catch (KeyNotFoundException) 
        {
            return NotFound();
        }
    }

    /// <summary>Kullanıcının kendi fişleri.</summary>
    [HttpGet("my")]
    public async Task<IActionResult> GetMyReceipts(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken ct = default)
    {
        var result = await _service.GetUserReceiptsAsync(UserId, TenantId, page, pageSize, ct);
        return Ok(result);
    }

    /// <summary>Departman fişleri — Manager, Finance, Admin.</summary>
    [HttpGet("department/{departmentId:guid}")]
    [Authorize(Roles = "Manager,Finance,Admin")]
    public async Task<IActionResult> GetDepartmentReceipts(
        Guid departmentId,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken ct = default)
    {
        var result = await _service.GetDepartmentReceiptsAsync(departmentId, TenantId, page, pageSize, ct);
        return Ok(result);
    }

    /// <summary>Yüksek riskli fişler — Finance, Admin.</summary>
    [HttpGet("high-risk")]
    [Authorize(Roles = "Finance,Admin")]
    public async Task<IActionResult> GetHighRisk(
        [FromQuery] int minScore = 60,
        CancellationToken ct = default)
    {
        var result = await _service.GetHighRiskAsync(TenantId, minScore, ct);
        return Ok(result);
    }

    /// <summary>Muhasebe için onaylı fişleri CSV olarak dışa aktar.</summary>
    [HttpGet("export-csv")]
    [Authorize(Roles = "Manager,Finance,Admin")]
    public async Task<IActionResult> ExportToCsv(CancellationToken ct)
    {
        var csv = await _service.ExportApprovedReceiptsToCsvAsync(TenantId, DeptId, ct);
        var bytes = System.Text.Encoding.UTF8.GetBytes(csv);
        return File(bytes, "text/csv", $"Masraflar_{DateTime.Now:yyyyMMdd}.csv");
    }

    /// <summary>Fiş onayla — Manager, Finance, Admin.</summary>
    [HttpPost("{id:guid}/approve")]
    [Authorize(Roles = "Manager,Finance,Admin")]
    public async Task<IActionResult> Approve(Guid id, CancellationToken ct)
    {
        var result = await _service.ApproveAsync(id, TenantId, UserId, UserRole.ToLowerInvariant(), DeptId, ct);
        return Ok(result);
    }

    /// <summary>Fiş reddet — Manager, Finance, Admin.</summary>
    [HttpPost("{id:guid}/reject")]
    [Authorize(Roles = "Manager,Finance,Admin")]
    public async Task<IActionResult> Reject(
        Guid id,
        [FromBody] ApproveRejectRequest req,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(req.Reason))
            return BadRequest(new { error = "Red gerekçesi zorunludur" });

        var result = await _service.RejectAsync(id, TenantId, UserId, UserRole.ToLowerInvariant(), DeptId, req.Reason!, ct);
        return Ok(result);
    }

    /// <summary>AI servisi fraud sonucunu bu endpoint'e callback yapar.
    /// Güvenlik: InternalNetworkMiddleware Docker iç ağı dışındaki erişimleri engeller.
    /// </summary>
    [HttpPost("{id:guid}/fraud-callback")]
    [AllowAnonymous]  // IP doğrulaması InternalNetworkMiddleware'de yapılır
    public async Task<IActionResult> FraudCallback(
        Guid id,
        [FromBody] FraudCallbackRequest req,
        CancellationToken ct)
    {
        if (req.ReceiptId != id.ToString())
            return BadRequest(new { error = "ID uyumsuzluğu" });

        await _service.HandleFraudCallbackAsync(Guid.Empty, req, ct);
        return Ok(new { message = "Fraud sonucu işlendi" });
    }
}

// ──────────────────────────────────────────────────────────────
[ApiController]
[Route("api/budgets")]
[Authorize(Roles = "Manager,Finance,Admin")]
public class BudgetsController : ControllerBase
{
    private readonly ReceiptService _service;

    public BudgetsController(ReceiptService service) => _service = service;

    private Guid TenantId => Guid.Parse(User.FindFirstValue("tenant_id")!);

    [HttpGet("{departmentId:guid}/{year:int}/{month:int}")]
    public async Task<IActionResult> GetStatus(
        Guid departmentId, int year, int month,
        CancellationToken ct)
    {
        var result = await _service.GetBudgetStatusAsync(
            departmentId, TenantId, year, month, "Departman", ct);

        return result is null ? NotFound(new { error = "Bütçe limiti tanımlı değil" }) : Ok(result);
    }
}
