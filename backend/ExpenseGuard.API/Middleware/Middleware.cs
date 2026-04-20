using System.Collections.Concurrent;
using System.Text.Json;
using ExpenseGuard.Infrastructure.Persistence;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace ExpenseGuard.API.Middleware;

// ════════════════════════════════════════════════════════════════
// 1. TenantMiddleware — X-Tenant-Domain header'dan tenant çöz
// ════════════════════════════════════════════════════════════════
public class TenantMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<TenantMiddleware> _logger;

    private static readonly HashSet<string> _publicPaths = new(StringComparer.OrdinalIgnoreCase)
    {
        "/health",
        "/swagger",
        "/swagger/v1/swagger.json",
    };

    public TenantMiddleware(RequestDelegate next, ILogger<TenantMiddleware> logger)
    {
        _next   = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext ctx, IServiceProvider services)
    {
        var path = ctx.Request.Path.Value ?? "";

        if (ctx.Request.Method == "OPTIONS" || _publicPaths.Any(p => path.StartsWith(p, StringComparison.OrdinalIgnoreCase)))
        {
            await _next(ctx);
            return;
        }

        var domain = ctx.Request.Headers["X-Tenant-Domain"].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(domain))
        {
            if (path.Contains("fraud-callback", StringComparison.OrdinalIgnoreCase))
            {
                ctx.Items["TenantId"] = Guid.Empty;
                await _next(ctx);
                return;
            }

            ctx.Response.StatusCode = 400;
            await ctx.Response.WriteAsJsonAsync(new { error = "X-Tenant-Domain header zorunludur" });
            return;
        }

        using var scope  = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var tenant = await db.Tenants
            .FirstOrDefaultAsync(t => t.Domain == domain.ToLowerInvariant() && t.IsActive);

        if (tenant is null)
        {
            _logger.LogWarning("Geçersiz/pasif tenant domain denemesi: {Domain}", domain);
            ctx.Response.StatusCode = 401;
            await ctx.Response.WriteAsJsonAsync(new { error = "Geçersiz tenant" });
            return;
        }

        ctx.Items["TenantId"] = tenant.Id;
        await _next(ctx);
    }
}

// ════════════════════════════════════════════════════════════════
// 2. ErrorHandlingMiddleware — Global hata yönetimi
//    Production'da stack trace / iç hata detayı asla dışarı sızmaz
// ════════════════════════════════════════════════════════════════
public class ErrorHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ErrorHandlingMiddleware> _logger;
    private readonly IHostEnvironment _env;

    public ErrorHandlingMiddleware(
        RequestDelegate next,
        ILogger<ErrorHandlingMiddleware> logger,
        IHostEnvironment env)
    {
        _next   = next;
        _logger = logger;
        _env    = env;
    }

    public async Task InvokeAsync(HttpContext ctx)
    {
        try
        {
            await _next(ctx);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, "Kayıt bulunamadı");
            ctx.Response.StatusCode  = 404;
            ctx.Response.ContentType = "application/json";
            await ctx.Response.WriteAsync(JsonSerializer.Serialize(new { error = ex.Message }));
        }
        catch (UnauthorizedAccessException ex)
        {
            _logger.LogWarning(ex, "Yetkisiz erişim");
            ctx.Response.StatusCode  = 403;
            ctx.Response.ContentType = "application/json";
            await ctx.Response.WriteAsync(JsonSerializer.Serialize(new { error = "Erişim reddedildi" }));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Beklenmeyen hata: {Path}", ctx.Request.Path);
            ctx.Response.StatusCode  = 500;
            ctx.Response.ContentType = "application/json";

            // 🔒 GÜVENLİK: Production'da iç hata detayı asla client'a gönderilmez
            var response = _env.IsProduction()
                ? new { error = "Sunucu hatası. Lütfen daha sonra tekrar deneyin." }
                : new { error = $"[DEV] {ex.Message}" };

            await ctx.Response.WriteAsync(JsonSerializer.Serialize(response));
        }
    }
}

// ════════════════════════════════════════════════════════════════
// 3. SecurityHeadersMiddleware — HTTP güvenlik başlıkları
//    HSTS, CSP, X-Frame-Options, X-Content-Type-Options, vb.
// ════════════════════════════════════════════════════════════════
public class SecurityHeadersMiddleware
{
    private readonly RequestDelegate _next;

    public SecurityHeadersMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext ctx)
    {
        var headers = ctx.Response.Headers;

        // Clickjacking önleme
        headers["X-Frame-Options"] = "DENY";

        // MIME sniffing saldırılarını engelle
        headers["X-Content-Type-Options"] = "nosniff";

        // Referrer bilgisini minimum düzeyde tut
        headers["Referrer-Policy"] = "strict-origin-when-cross-origin";

        // XSS koruması (eski tarayıcılar için)
        headers["X-XSS-Protection"] = "1; mode=block";

        // Permissions Policy — gereksiz tarayıcı özelliklerini devre dışı bırak
        headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";

        // Content Security Policy — sadece kendi kaynaklarımıza izin ver
        headers["Content-Security-Policy"] =
            "default-src 'self'; " +
            "script-src 'self' 'unsafe-inline'; " +
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
            "font-src 'self' https://fonts.gstatic.com; " +
            "img-src 'self' data: https:; " +
            "connect-src 'self'; " +
            "frame-ancestors 'none';";

        // HSTS — HTTPS zorunluluğu (1 yıl + subdomain)
        if (ctx.Request.IsHttps)
            headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload";

        // Sunucu bilgisini gizle
        headers["Server"] = "ExpenseGuard";

        await _next(ctx);
    }
}

// ════════════════════════════════════════════════════════════════
// 4. RateLimitMiddleware — Brute-force ve DoS koruması
//    Login endpoint'ine IP başına 10 istek/dakika limiti
//    Genel API'ye IP başına 200 istek/dakika limiti
// ════════════════════════════════════════════════════════════════
public class RateLimitMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RateLimitMiddleware> _logger;

    // IP → (istek sayısı, pencere başlangıcı)
    private static readonly ConcurrentDictionary<string, (int Count, DateTime Window)> _loginAttempts  = new();
    private static readonly ConcurrentDictionary<string, (int Count, DateTime Window)> _uploadAttempts = new();
    private static readonly ConcurrentDictionary<string, (int Count, DateTime Window)> _globalAttempts = new();

    private const int LoginLimit   = 10;   // /dakika login denemesi
    private const int UploadLimit  = 5;    // /dakika fiş yükleme denemesi
    private const int GlobalLimit  = 200;  // /dakika genel API
    private static readonly TimeSpan Window = TimeSpan.FromMinutes(1);

    public RateLimitMiddleware(RequestDelegate next, ILogger<RateLimitMiddleware> logger)
    {
        _next   = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext ctx)
    {
        var ip   = ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var path = ctx.Request.Path.Value ?? "";

        // CORS Preflight isteklerini limitleme dışı tut
        if (ctx.Request.Method == "OPTIONS")
        {
            await _next(ctx);
            return;
        }

        // Login endpoint'i için sıkı limit
        if (path.Contains("/auth/login", StringComparison.OrdinalIgnoreCase))
        {
            if (IsRateLimited(_loginAttempts, ip, LoginLimit))
            {
                _logger.LogWarning("Login rate limit aşıldı. IP: {IP}", ip);
                ctx.Response.StatusCode = 429;
                ctx.Response.Headers["Retry-After"] = "60";
                await ctx.Response.WriteAsJsonAsync(new
                {
                    error = "Çok fazla giriş denemesi. Lütfen 1 dakika bekleyiniz."
                });
                return;
            }
        }

        // Fiş yükleme (Upload) endpoint'i için sıkı limit (AI faturası şişmesini engeller)
        if (ctx.Request.Method == "POST" && path.Contains("/api/receipts", StringComparison.OrdinalIgnoreCase))
        {
            if (IsRateLimited(_uploadAttempts, ip, UploadLimit))
            {
                _logger.LogWarning("Upload rate limit aşıldı. IP: {IP}", ip);
                ctx.Response.StatusCode = 429;
                ctx.Response.Headers["Retry-After"] = "60";
                await ctx.Response.WriteAsJsonAsync(new
                {
                    error = "Çok fazla fiş yüklüyorsunuz. Lütfen 1 dakika bekleyiniz."
                });
                return;
            }
        }

        // Genel API limiti
        if (IsRateLimited(_globalAttempts, ip, GlobalLimit))
        {
            _logger.LogWarning("Global rate limit aşıldı. IP: {IP}", ip);
            ctx.Response.StatusCode = 429;
            ctx.Response.Headers["Retry-After"] = "60";
            await ctx.Response.WriteAsJsonAsync(new
            {
                error = "İstek limiti aşıldı. Lütfen bekleyiniz."
            });
            return;
        }

        await _next(ctx);
    }

    private static bool IsRateLimited(
        ConcurrentDictionary<string, (int, DateTime)> store,
        string key, int limit)
    {
        var now = DateTime.UtcNow;
        store.AddOrUpdate(
            key,
            addValue: (1, now),
            updateValueFactory: (_, existing) =>
            {
                var (count, window) = existing;
                if (now - window > Window)
                    return (1, now);          // Pencere sıfırla
                return (count + 1, window);  // Sayacı artır
            }
        );

        return store.TryGetValue(key, out var current) && current.Item1 > limit;
    }
}

// ════════════════════════════════════════════════════════════════
// 5. InternalNetworkMiddleware — Fraud callback güvenliği
//    Sadece doğru X-Internal-Secret başlığına sahip isteklere izin ver
// ════════════════════════════════════════════════════════════════
public class InternalNetworkMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<InternalNetworkMiddleware> _logger;
    private readonly string _expectedSecret;

    public InternalNetworkMiddleware(RequestDelegate next, ILogger<InternalNetworkMiddleware> logger, IConfiguration config)
    {
        _next   = next;
        _logger = logger;
        _expectedSecret = config["InternalApiSecret"] ?? "SuperSecretInternalToken_For_FraudCallback_123!";
    }

    public async Task InvokeAsync(HttpContext ctx)
    {
        var path = ctx.Request.Path.Value ?? "";

        if (ctx.Request.Method == "OPTIONS" || path.Contains("fraud-callback", StringComparison.OrdinalIgnoreCase))
        {
            if (!ctx.Request.Headers.TryGetValue("X-Internal-Secret", out var providedSecret) ||
                providedSecret != _expectedSecret)
            {
                var ip = ctx.Connection.RemoteIpAddress?.ToString() ?? "";
                _logger.LogWarning("Fraud callback geçersiz secret ile erişim engellendi. IP: {IP}", ip);
                ctx.Response.StatusCode = 401;
                await ctx.Response.WriteAsJsonAsync(new { error = "Geçersiz Internal API Secret" });
                return;
            }
        }

        await _next(ctx);
    }
}
