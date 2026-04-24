using System.Text;
using Serilog;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using RabbitMQ.Client;
using ExpenseGuard.Application.Services;
using ExpenseGuard.Domain.Interfaces;
using ExpenseGuard.Infrastructure.Cache;
using ExpenseGuard.Infrastructure.Messaging;
using ExpenseGuard.Infrastructure.Persistence;
using ExpenseGuard.Infrastructure.Repositories;
using ExpenseGuard.Infrastructure.Security;
using ExpenseGuard.Infrastructure.Storage;
using ExpenseGuard.Infrastructure.Billing;
using ExpenseGuard.Infrastructure.Notifications;
using ExpenseGuard.API.Services;
using ExpenseGuard.API.Middleware;

var builder = WebApplication.CreateBuilder(args);
var cfg     = builder.Configuration;

// ── SERILOG (LOGGING & OBSERVABILITY) ────────────────────────
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(cfg)
    .Enrich.FromLogContext()
    .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
    .WriteTo.File("Logs/expenseguard-.log", rollingInterval: RollingInterval.Day,
                  outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}")
    .CreateLogger();

builder.Host.UseSerilog(); // Varsayılan .NET Logger yerine Serilog kullan

// ── POSTGRESQL (Entity Framework Core) ────────────────────
builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseNpgsql(cfg.GetConnectionString("Postgres"),
        npgsql => npgsql.MigrationsAssembly("ExpenseGuard.Infrastructure")));

// ── REDIS (IDistributedCache) ──────────────────────────────
builder.Services.AddStackExchangeRedisCache(o =>
    o.Configuration = cfg.GetConnectionString("Redis") ?? "redis:6379");

// ── RABBITMQ ───────────────────────────────────────────────
builder.Services.AddSingleton<IConnection>(_ =>
{
    var factory = new ConnectionFactory
    {
        Uri = new Uri(cfg.GetConnectionString("RabbitMQ") ?? "amqp://guest:guest@rabbitmq:5672/"),
    };
    return factory.CreateConnectionAsync().GetAwaiter().GetResult();
});

// ── DI BINDINGS — Repositories ────────────────────────────
builder.Services.AddScoped<IReceiptRepository, ReceiptRepository>();
builder.Services.AddScoped<IUserRepository,    UserRepository>();
builder.Services.AddScoped<IBudgetRepository,  BudgetRepository>();
builder.Services.AddScoped<IDepartmentRepository, DepartmentRepository>();

// ── DI BINDINGS — Services ─────────────────────────────────
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ITenantProvider,     TenantProvider>();
builder.Services.AddScoped<ICacheService,       RedisService>();
builder.Services.AddScoped<IMessagePublisher,   RabbitMQPublisher>();
builder.Services.AddScoped<IEncryptionService,  EncryptionService>();
builder.Services.AddScoped<IStorageService,     AwsS3StorageService>();
builder.Services.AddScoped<IEmailService,       SmtpEmailService>();
builder.Services.AddScoped<BillingService>();
builder.Services.AddScoped<AuthService>();       // AppDbContext bağımlılığını DI karşılar
builder.Services.AddScoped<ReceiptService>();
builder.Services.AddScoped<AnalyticsService>();
builder.Services.AddHttpClient<ITaxVerificationService, TaxVerificationService>();

// ── Faz 3 (Büyüme) DI Kayıtları ────────────────────────────
builder.Services.AddHttpClient<IExchangeRateService, ExchangeRateService>();
builder.Services.AddScoped<IERPIntegrationService, LogoIntegrationService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<IMLExportService, MLExportService>();
builder.Services.AddScoped<IDataAnonymizationService, DataAnonymizationService>();

// ── JWT AUTHENTICATION ─────────────────────────────────────
var jwtSecret = cfg["Jwt:Secret"] ?? throw new Exception("JWT Secret eksik!");

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey         = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
            ValidateIssuer           = true,
            ValidIssuer              = cfg["Jwt:Issuer"] ?? "ExpenseGuard",
            ValidateAudience         = true,
            ValidAudience            = cfg["Jwt:Audience"] ?? "ExpenseGuard",
            ClockSkew                = TimeSpan.FromSeconds(30),
            ValidateLifetime         = true,    // 🔒 Token süresi mutlaka kontrol edilmeli
        };
    });

// ── RBAC AUTHORIZATION ─────────────────────────────────────
builder.Services.AddAuthorizationBuilder()
    .AddPolicy("Employee", p => p.RequireRole("Employee", "Manager", "Finance", "Admin"))
    .AddPolicy("Manager",  p => p.RequireRole("Manager", "Finance", "Admin"))
    .AddPolicy("Finance",  p => p.RequireRole("Finance", "Admin"))
    .AddPolicy("Admin",    p => p.RequireRole("Admin"));

// ── CORS ───────────────────────────────────────────────────
// 🔒 GÜVENLİK: AllowAnyOrigin kaldırıldı, sadece env'den gelen izinli origin'ler
builder.Services.AddCors(o =>
    o.AddDefaultPolicy(p =>
    {
        var allowed = (cfg["AllowedOrigins"] ?? "http://localhost:3000,http://localhost:5500,http://127.0.0.1:5500")
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        p.WithOrigins(allowed)
         .AllowAnyHeader()
         .AllowAnyMethod();
    }));

// ── SWAGGER/OPENAPI ────────────────────────────────────────
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title   = "ExpenseGuard Pro API",
        Version = "v1",
        Description = "Kurumsal Gider Yönetimi & Fraud Tespit API",
    });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name   = "Authorization",
        Type   = SecuritySchemeType.Http,
        Scheme = "Bearer",
        In     = ParameterLocation.Header,
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {{
        new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } },
        Array.Empty<string>()
    }});
});

builder.Services.AddControllers();

var app = builder.Build();

// ── MIDDLEWARE PIPELINE ────────────────────────────────────
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "ExpenseGuard Pro v1"));
}

app.UseHttpsRedirection();

app.UseCors();

// 🔒 GÜVENLİK MIDDLEWARE SIRASI ÖNEMLİDİR:
app.UseMiddleware<SecurityHeadersMiddleware>();   // 1. Güvenlik başlıkları (her zaman ilk)
app.UseMiddleware<RateLimitMiddleware>();          // 2. Rate limiting (brute-force/DDoS)
app.UseMiddleware<InternalNetworkMiddleware>();   // 3. İç ağ koruma (fraud callback)
app.UseMiddleware<ErrorHandlingMiddleware>();      // 4. Hata yönetimi
app.UseMiddleware<TenantMiddleware>();             // 5. Tenant çözümleme

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", async (ExpenseGuard.Infrastructure.Persistence.AppDbContext db, RabbitMQ.Client.IConnection rabbitConn) => 
{
    bool dbOk = await db.Database.CanConnectAsync();
    bool rabbitOk = rabbitConn.IsOpen;

    return new {
        status = (dbOk && rabbitOk) ? "healthy" : "unhealthy",
        version = "1.0.0",
        services = new {
            database = dbOk ? "connected" : "disconnected",
            rabbitmq = rabbitOk ? "connected" : "disconnected"
        },
        time = DateTime.UtcNow
    };
});

app.MapControllers();

// ── DB MIGRATION (dev ortamında otomatik) ──────────────────
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();
}

app.Run();
