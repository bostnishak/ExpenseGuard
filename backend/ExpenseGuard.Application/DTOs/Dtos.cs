// ============================================================
// DTOs — Uygulama katmanı veri transfer nesneleri
// ============================================================
namespace ExpenseGuard.Application.DTOs;

// AUTH
public record LoginRequest(string Email, string Password);
public record LoginResponse(string Token, string RefreshToken, long RefreshTokenExpiresIn, UserDto User);
public record RefreshTokenRequest(string RefreshToken);
public record UserDto(Guid Id, string FullName, string Email, string Role, Guid? DepartmentId);
public record RegisterRequest(string Email, string Password, string FirstName, string LastName);

// RECEIPTS
public record CreateReceiptRequest(
    string?   ImageBase64   = null,
    string?   Method        = null, // "OCR_MOBILE" veya "MANUAL"
    DateOnly? ReceiptDate   = null,
    decimal?  Amount        = null,
    string?   Category      = "other",
    string?   VendorName    = null,
    decimal?  TaxAmount     = null,
    decimal?  TaxRate       = null,
    string    Currency      = "TRY"
);

public record ReceiptResponse(
    Guid     Id,
    string   Status,
    string   RiskLevel,
    int?     FraudScore,
    string?  FraudReasons,
    decimal  Amount,
    string   Category,
    string?  VendorName,
    DateOnly ReceiptDate,
    string   SubmittedByName,
    DateTimeOffset SubmittedAt
);

public record ReceiptListResponse(
    IReadOnlyList<ReceiptResponse> Items,
    int TotalCount,
    int Page,
    int PageSize
);

public record ApproveRejectRequest(string? Reason = null);

// BUDGET
public record BudgetUpsertRequest(
    Guid    DepartmentId,
    int     Year,
    int     Month,
    decimal LimitAmount,
    string  Currency = "TRY"
);

public record BudgetStatusResponse(
    Guid    DepartmentId,
    string  DepartmentName,
    decimal LimitAmount,
    decimal SpentAmount,
    decimal RemainingAmount,
    decimal UsagePercent,
    bool    IsExceeded
);

// FRAUD CALLBACK (Python AI → .NET)
public record FraudCallbackRequest(
    string  ReceiptId,
    int     FraudScore,
    string  RiskLevel,
    string  RecommendedAction,
    string? LlmReasoning,
    IReadOnlyList<FraudRuleResult> RulesChecked
);
public record FraudRuleResult(string Rule, string Message, bool Passed);
