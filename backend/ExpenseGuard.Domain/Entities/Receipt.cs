// ============================================================
// ExpenseGuard.Domain — Entity: Receipt
// ============================================================
using ExpenseGuard.Domain.Enums;

namespace ExpenseGuard.Domain.Entities;

public class Receipt
{
    public Guid   Id            { get; private set; } = Guid.NewGuid();
    public Guid   TenantId      { get; private set; }
    public Guid   DepartmentId  { get; private set; }
    public Guid   SubmittedBy   { get; private set; }
    public Guid?  ApprovedBy    { get; private set; }

    public DateOnly      ReceiptDate  { get; private set; }
    public string?       VendorName   { get; private set; }
    public string        Category     { get; private set; } = "other";

    // Finansal veriler (Infrastructure katmanında şifrelenir)
    public decimal Amount       { get; private set; }
    public decimal? TaxAmount   { get; private set; }
    public decimal? TaxRate     { get; private set; }
    public string  Currency     { get; private set; } = "TRY";

    // OCR / AI
    public string?        ImagePath    { get; private set; }
    public string?        OcrRawText   { get; private set; }
    public int?           FraudScore   { get; private set; }
    public string?        FraudReasons { get; private set; }  // JSON array
    public ReceiptStatus  Status       { get; private set; } = ReceiptStatus.Pending;
    public RiskLevel      RiskLevel    { get; private set; } = RiskLevel.Pending;
    public string?        RejectionReason { get; private set; }

    public DateTimeOffset SubmittedAt  { get; private set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? ProcessedAt { get; private set; }
    public DateTimeOffset UpdatedAt    { get; private set; } = DateTimeOffset.UtcNow;

    // ── Factory Method ──────────────────────────────────────
    public static Receipt Create(
        Guid tenantId, Guid departmentId, Guid submittedBy,
        DateOnly receiptDate, decimal amount, string category,
        string? vendorName = null, decimal? taxAmount = null, decimal? taxRate = null)
    {
        return new Receipt
        {
            TenantId     = tenantId,
            DepartmentId = departmentId,
            SubmittedBy  = submittedBy,
            ReceiptDate  = receiptDate,
            Amount       = amount,
            Category     = category,
            VendorName   = vendorName,
            TaxAmount    = taxAmount,
            TaxRate      = taxRate,
        };
    }

    // ── Domain Methods ──────────────────────────────────────
    public void SetOcrData(string? imagePath, string? rawText)
    {
        ImagePath  = imagePath;
        OcrRawText = rawText;
        UpdatedAt  = DateTimeOffset.UtcNow;
    }

    public void SetFraudResult(int score, RiskLevel risk, string? reasons)
    {
        FraudScore   = score;
        RiskLevel    = risk;
        FraudReasons = reasons;
        ProcessedAt  = DateTimeOffset.UtcNow;
        UpdatedAt    = DateTimeOffset.UtcNow;

        // Otomatik karar
        Status = score switch
        {
            <= 25 => ReceiptStatus.Approved,
            >= 80 => ReceiptStatus.Rejected,
            _     => ReceiptStatus.Flagged,
        };
    }

    public void Approve(Guid approverId)
    {
        Status     = ReceiptStatus.Approved;
        ApprovedBy = approverId;
        UpdatedAt  = DateTimeOffset.UtcNow;
    }

    public void Reject(Guid approverId, string reason)
    {
        Status          = ReceiptStatus.Rejected;
        ApprovedBy      = approverId;
        RejectionReason = reason;
        UpdatedAt       = DateTimeOffset.UtcNow;
    }

    public void MarkAiProcessing()
    {
        Status    = ReceiptStatus.AiProcessing;
        UpdatedAt = DateTimeOffset.UtcNow;
    }
}
