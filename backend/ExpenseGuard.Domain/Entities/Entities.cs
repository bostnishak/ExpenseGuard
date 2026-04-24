using ExpenseGuard.Domain.Enums;
using System.Collections.Generic;

namespace ExpenseGuard.Domain.Entities;

public class User
{
    public Guid          Id           { get; set; } = Guid.NewGuid();
    public Guid          TenantId     { get; set; }
    public Guid?         DepartmentId { get; set; }
    public string        Email        { get; set; } = string.Empty;
    public string        PasswordHash { get; set; } = string.Empty;
    public string        FirstName    { get; set; } = string.Empty;
    public string        LastName     { get; set; } = string.Empty;
    public UserRole      Role         { get; set; } = UserRole.Employee;
    public bool          IsActive     { get; set; } = true;
    public DateTimeOffset CreatedAt   { get; set; } = DateTimeOffset.UtcNow;
    
    // Email Verification Phase 1
    public bool          IsEmailVerified       { get; set; } = false;
    public string?       VerificationToken     { get; set; }
    public DateTimeOffset? VerificationExpiresAt { get; set; }

    public string FullName => $"{FirstName} {LastName}";

    // Navigation
    public Tenant?     Tenant        { get; set; }
    public Department? Department    { get; set; }
    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
}

public class Tenant
{
    public Guid   Id        { get; set; } = Guid.NewGuid();
    public string Name      { get; set; } = string.Empty;
    public string Domain    { get; set; } = string.Empty;
    public string Plan      { get; set; } = "starter";
    public bool   IsActive  { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    // ── Stripe Billing ────────────────────────────────────────
    public string? StripeCustomerId     { get; set; }
    public string? SubscriptionId       { get; set; }
    public string  SubscriptionStatus   { get; set; } = "trialing"; // trialing, active, past_due, canceled
    public DateTimeOffset? TrialEndsAt  { get; set; }

    // ── White-Label (Faz 2) ───────────────────────────────────
    public string? ThemeColor           { get; set; }
    public string? LogoUrl              { get; set; }
    public string? CustomDomain         { get; set; }

    // ── ERP Integration (Faz 3) ───────────────────────────────
    public string? ErpProvider          { get; set; } // Logo, Netsis, SAP
    public string? ErpApiKey            { get; set; }
    public string? ErpEndpoint          { get; set; }
}

public class Department
{
    public Guid   Id       { get; set; } = Guid.NewGuid();
    public Guid   TenantId { get; set; }
    public string Name     { get; set; } = string.Empty;
    public string Code     { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public Tenant? Tenant { get; set; }
}

public class BudgetLimit
{
    public Guid    Id           { get; set; } = Guid.NewGuid();
    public Guid    TenantId     { get; set; }
    public Guid    DepartmentId { get; set; }
    public short   PeriodYear   { get; set; }
    public short   PeriodMonth  { get; set; }
    public decimal LimitAmount  { get; set; }
    public string  Currency     { get; set; } = "TRY";
    public Guid?   CreatedBy    { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public Department? Department { get; set; }
}

public class AuditLog
{
    public long   Id         { get; set; }
    public Guid   TenantId   { get; set; }
    public string TableName  { get; set; } = string.Empty;
    public Guid   RecordId   { get; set; }
    public string Operation  { get; set; } = string.Empty;
    public Guid?  ChangedBy  { get; set; }
    public DateTimeOffset ChangedAt { get; set; }
    public string? OldValues { get; set; }
    public string? NewValues { get; set; }
}

// ──────────────────────────────────────────────────────────────
// Refresh Token — veritabanında saklanır, rotation stratejisi
// ──────────────────────────────────────────────────────────────
public class RefreshToken
{
    public Guid          Id          { get; set; } = Guid.NewGuid();
    public Guid          UserId      { get; set; }
    public Guid          TenantId    { get; set; }
    public string        Token       { get; set; } = string.Empty;  // SHA-256 hash olarak sakla
    public DateTimeOffset ExpiresAt  { get; set; }
    public DateTimeOffset CreatedAt  { get; set; } = DateTimeOffset.UtcNow;
    public bool          IsRevoked   { get; set; } = false;
    public string?       ReplacedBy  { get; set; }  // Token rotation — hangi token ile değiştirildi
    public string?       CreatedByIp { get; set; }

    public bool IsExpired  => DateTimeOffset.UtcNow >= ExpiresAt;
    public bool IsActive   => !IsRevoked && !IsExpired;

    public User? User { get; set; }
}

// ── Faz 3: Mobil Onay / Bildirimler ───────────────────────────
public class Notification
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid TenantId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public bool IsRead { get; set; } = false;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public class UserDeviceToken
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string DeviceToken { get; set; } = string.Empty; // FCM Token
    public string DeviceType { get; set; } = "ios"; // ios, android, web
    public DateTimeOffset LastUsedAt { get; set; } = DateTimeOffset.UtcNow;
}
