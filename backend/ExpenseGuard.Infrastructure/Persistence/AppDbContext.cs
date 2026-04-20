using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using ExpenseGuard.Domain.Entities;
using ExpenseGuard.Domain.Interfaces;

namespace ExpenseGuard.Infrastructure.Persistence;

public class AppDbContext : DbContext
{
    private readonly ITenantProvider? _tenantProvider;

    public AppDbContext(DbContextOptions<AppDbContext> options, ITenantProvider? tenantProvider = null) : base(options) 
    {
        _tenantProvider = tenantProvider;
    }

    public DbSet<Tenant>        Tenants       { get; set; } = null!;
    public DbSet<Department>    Departments   { get; set; } = null!;
    public DbSet<User>          Users         { get; set; } = null!;
    public DbSet<Receipt>       Receipts      { get; set; } = null!;
    public DbSet<BudgetLimit>   BudgetLimits  { get; set; } = null!;
    public DbSet<AuditLog>      AuditLogs     { get; set; } = null!;
    public DbSet<RefreshToken>  RefreshTokens { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder mb)
    {
        // Tenant
        mb.Entity<Tenant>(e => {
            e.HasKey(t => t.Id);
            e.Property(t => t.Name).HasMaxLength(200).IsRequired();
            e.Property(t => t.Domain).HasMaxLength(100).IsRequired();
            e.HasIndex(t => t.Domain).IsUnique();
            e.ToTable("tenants");
        });

        var tenantId = _tenantProvider?.GetTenantId() ?? Guid.Empty;

        // Department
        mb.Entity<Department>(e => {
            e.HasKey(d => d.Id);
            e.Property(d => d.Code).HasMaxLength(20).IsRequired();
            e.HasIndex(d => new { d.TenantId, d.Code }).IsUnique();
            e.HasOne(d => d.Tenant).WithMany().HasForeignKey(d => d.TenantId);
            e.ToTable("departments");
            if (tenantId != Guid.Empty) e.HasQueryFilter(d => d.TenantId == tenantId);
        });

        // User
        mb.Entity<User>(e => {
            e.HasKey(u => u.Id);
            e.Property(u => u.Email).HasMaxLength(254).IsRequired();
            e.HasIndex(u => new { u.TenantId, u.Email }).IsUnique();
            e.Property(u => u.Role).HasConversion<string>();
            e.HasOne(u => u.Tenant).WithMany().HasForeignKey(u => u.TenantId);
            e.HasOne(u => u.Department).WithMany().HasForeignKey(u => u.DepartmentId);
            e.ToTable("users");
            if (tenantId != Guid.Empty) e.HasQueryFilter(u => u.TenantId == tenantId);
        });

        // Receipt — private setters için shadow property mapping
        mb.Entity<Receipt>(e => {
            e.HasKey(r => r.Id);
            e.Property(r => r.Status).HasConversion<string>();
            e.Property(r => r.RiskLevel).HasConversion<string>();
            e.Property(r => r.Category).HasMaxLength(50);
            e.Property(r => r.Currency).HasMaxLength(3).HasDefaultValue("TRY");
            e.Property(r => r.Amount).HasColumnName("amount_display")
                .HasPrecision(15, 2);
            e.ToTable("expense_receipts");
            if (tenantId != Guid.Empty) e.HasQueryFilter(r => r.TenantId == tenantId);
        });

        // BudgetLimit
        mb.Entity<BudgetLimit>(e => {
            e.HasKey(b => b.Id);
            e.HasIndex(b => new { b.DepartmentId, b.PeriodYear, b.PeriodMonth }).IsUnique();
            e.Property(b => b.LimitAmount).HasPrecision(15, 2);
            e.Property(b => b.Currency).HasMaxLength(3);
            e.HasOne(b => b.Department).WithMany().HasForeignKey(b => b.DepartmentId);
            e.ToTable("budget_limits");
            if (tenantId != Guid.Empty) e.HasQueryFilter(b => b.TenantId == tenantId);
        });

        // AuditLog — read-only, sadece PostgreSQL trigger yazar
        mb.Entity<AuditLog>(e => {
            e.HasKey(a => a.Id);
            e.Property(a => a.Id).ValueGeneratedOnAdd();
            e.ToTable("audit_log");
        });

        // RefreshToken — rotation stratejisi ile güvenli token yönetimi
        mb.Entity<RefreshToken>(e =>
        {
            e.HasKey(rt => rt.Id);
            e.Property(rt => rt.Token).HasMaxLength(512).IsRequired();
            e.HasIndex(rt => rt.Token).IsUnique();
            e.HasOne(rt => rt.User)
             .WithMany(u => u.RefreshTokens)
             .HasForeignKey(rt => rt.UserId)
             .OnDelete(DeleteBehavior.Cascade);
            e.ToTable("refresh_tokens");
            if (tenantId != Guid.Empty) e.HasQueryFilter(rt => rt.TenantId == tenantId);
        });

        // 🐍 PostgreSQL için snake_case isimlendirme kuralını uygula
        foreach (var entity in mb.Model.GetEntityTypes())
        {
            // Tablo isimleri zaten set edildi (ToTable), ancak garantiye alalım
            // property isimlendirmeleri
            foreach (var property in entity.GetProperties())
            {
                var column = property.GetColumnName(StoreObjectIdentifier.Table(entity.GetTableName()!, entity.GetSchema()));
                // Eğer manuel bir isim verilmemişse (amount_display gibi), snake_case'e çevir
                if (column == property.Name)
                {
                    property.SetColumnName(ToSnakeCase(property.Name));
                }
            }
        }
    }

    private static string ToSnakeCase(string str)
    {
        if (string.IsNullOrEmpty(str)) return str;
        var result = new System.Text.StringBuilder();
        for (int i = 0; i < str.Length; i++)
        {
            if (char.IsUpper(str[i]))
            {
                if (i > 0) result.Append('_');
                result.Append(char.ToLower(str[i]));
            }
            else
            {
                result.Append(str[i]);
            }
        }
        return result.ToString();
    }
}
