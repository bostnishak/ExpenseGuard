using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using ExpenseGuard.Infrastructure.Persistence;
using ExpenseGuard.Domain.Entities;
using ExpenseGuard.Application.Services;
using ExpenseGuard.Infrastructure.Billing;
using ExpenseGuard.Domain.Enums;
using ExpenseGuard.Domain.Interfaces;
using ExpenseGuard.Infrastructure.Security;

namespace ExpenseGuard.API.Controllers;

[ApiController]
[Route("api/super-admin")]
public class SuperAdminController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IConfiguration _config;
    private readonly AuthService _auth;
    private readonly BillingService _billing;
    private readonly IEmailService _email;

    public SuperAdminController(AppDbContext db, IConfiguration config, AuthService auth, BillingService billing, IEmailService email)
    {
        _db = db;
        _config = config;
        _auth = auth;
        _billing = billing;
        _email = email;
    }

    /// <summary>
    /// Yeni şirket (Tenant) ve o şirketin ilk Admin kullanıcısını oluşturur.
    /// Sadece X-SuperAdmin-Key başlığı ile çağrılabilir.
    /// </summary>
    [HttpPost("tenants")]
    [AllowAnonymous]
    public async Task<IActionResult> CreateTenant(
        [FromBody] CreateTenantRequest req,
        [FromHeader(Name = "X-SuperAdmin-Key")] string key,
        CancellationToken ct)
    {
        // InternalApiSecret ile koruyoruz (Basit bir Master Key yaklaşımı)
        var expectedKey = _config["InternalApiSecret"];
        if (string.IsNullOrWhiteSpace(expectedKey) || key != expectedKey)
        {
            return Unauthorized(new { error = "Geçersiz Super Admin anahtarı" });
        }

        if (await _db.Tenants.AnyAsync(t => t.Domain == req.Domain, ct))
        {
            return BadRequest(new { error = "Bu domain zaten kullanımda." });
        }

        // 1. Tenant oluştur
        var tenant = new Tenant { Name = req.Name, Domain = req.Domain };

        // 1.1. Stripe Customer oluştur
        var stripeCustomerId = await _billing.CreateCustomerAsync(tenant, req.AdminEmail, ct);
        tenant.StripeCustomerId = stripeCustomerId;
        tenant.TrialEndsAt = DateTimeOffset.UtcNow.AddDays(14); // 14 günlük deneme başlat

        _db.Tenants.Add(tenant);
        await _db.SaveChangesAsync(ct);

        // 2. Varsayılan departman oluştur (Admin için)
        var dept = new Department { TenantId = tenant.Id, Name = "Yönetim", Code = "YONETIM" };
        _db.Departments.Add(dept);
        await _db.SaveChangesAsync(ct);

        // 3. Admin kullanıcısını oluştur (AuthService Register)
        var registerReq = new ExpenseGuard.Application.DTOs.RegisterRequest(
            Email: req.AdminEmail,
            Password: req.AdminPassword,
            FirstName: "Sistem",
            LastName: "Yöneticisi"
        );
        
        var adminDto = await _auth.RegisterAsync(registerReq, tenant.Id, ct);

        // 4. Kullanıcının rolünü Admin yap ve departmana ata
        var user = await _db.Users.FindAsync(new object[] { adminDto.Id }, ct);
        if (user != null)
        {
            user.Role = UserRole.Admin;
            user.DepartmentId = dept.Id;
            await _db.SaveChangesAsync(ct);
        }

        // 5. Hoşgeldin maili at
        var loginLink = $"https://app.expenseguard.com/login?domain={tenant.Domain}";
        var body = $"Tebrikler, <b>{tenant.Name}</b> şirketi başarıyla oluşturuldu!<br><br>Yönetici paneline giriş yapmak için:<br><a href='{loginLink}'>{loginLink}</a><br>E-posta: {req.AdminEmail}<br>Şifre: <i>[Sizin belirlediğiniz şifre]</i>";
        
        await _email.SendEmailAsync(req.AdminEmail, "ExpenseGuard Pro - Şirket Hesabınız Açıldı!", body, ct);

        return Ok(new 
        { 
            message = "Tenant başarıyla oluşturuldu ve e-posta gönderildi.", 
            tenantId = tenant.Id,
            domain = tenant.Domain
        });
    }

    [HttpGet("tenants")]
    [AllowAnonymous]
    public async Task<IActionResult> GetTenants(
        [FromHeader(Name = "X-SuperAdmin-Key")] string key,
        CancellationToken ct)
    {
        var expectedKey = _config["InternalApiSecret"];
        if (string.IsNullOrWhiteSpace(expectedKey) || key != expectedKey)
            return Unauthorized();

        var tenants = await _db.Tenants
            .Select(t => new { t.Id, t.Name, t.Domain, t.Plan, t.CreatedAt })
            .ToListAsync(ct);

        return Ok(tenants);
    }
}

public record CreateTenantRequest(string Name, string Domain, string AdminEmail, string AdminPassword);
