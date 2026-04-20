using System.Text.Json;
using ExpenseGuard.Application.DTOs;
using ExpenseGuard.Domain.Entities;
using ExpenseGuard.Domain.Enums;
using ExpenseGuard.Domain.Interfaces;

namespace ExpenseGuard.Application.Services;

public class ReceiptService
{
    private readonly IReceiptRepository _receipts;
    private readonly IBudgetRepository  _budgets;
    private readonly ICacheService      _cache;
    private readonly IMessagePublisher  _publisher;
    private readonly IEncryptionService _encryption;
    private readonly IStorageService    _storage;

    private const string AI_QUEUE = "receipt.analyze";

    public ReceiptService(
        IReceiptRepository receipts,
        IBudgetRepository  budgets,
        ICacheService      cache,
        IMessagePublisher  publisher,
        IEncryptionService encryption,
        IStorageService    storage)
    {
        _receipts   = receipts;
        _budgets    = budgets;
        _cache      = cache;
        _publisher  = publisher;
        _encryption = encryption;
        _storage    = storage;
    }

    // ── Fiş Oluştur ─────────────────────────────────────────
    public async Task<ReceiptResponse> CreateAsync(
        CreateReceiptRequest req,
        Guid tenantId,
        Guid userId,
        Guid departmentId,
        string callbackBaseUrl,
        CancellationToken ct = default)
    {
        // 🔒 GÜVENLİK: Malicious File Upload & Magic Bytes Kontrolü
        if (!string.IsNullOrWhiteSpace(req.ImageBase64))
        {
            if (!IsValidImage(req.ImageBase64))
                throw new ArgumentException("Geçersiz dosya formatı. Sadece JPEG ve PNG desteklenmektedir.");
        }

        // Fiş tarihi veya tutar mobil tarafta eksik gönderilmiş olabilir (OCR yapılacaksa)
        // Şimdilik varsayılan değerlerle kaydediyoruz.
        var receiptDate = req.ReceiptDate ?? DateOnly.FromDateTime(DateTime.UtcNow);
        var amount = req.Amount ?? 0m;

        var receipt = Receipt.Create(
            tenantId:     tenantId,
            departmentId: departmentId,
            submittedBy:  userId,
            receiptDate:  receiptDate,
            amount:       amount,
            category:     req.Category ?? "other",
            vendorName:   req.VendorName,
            taxAmount:    req.TaxAmount,
            taxRate:      req.TaxRate
        );

        // 🚀 AWS S3'e Yükleme (Eğer Base64 görsel varsa)
        string? uploadedUrl = null;
        if (!string.IsNullOrWhiteSpace(req.ImageBase64))
        {
            // S3 servisine gönder, URL'i al
            uploadedUrl = await _storage.UploadFileAsync(
                fileName: $"receipts/{tenantId}/{Guid.NewGuid()}.jpg",
                base64Content: req.ImageBase64,
                contentType: "image/jpeg",
                ct: ct
            );
            receipt.SetOcrData(uploadedUrl, null); // Şimdilik sadece resim URL'si
        }

        receipt.MarkAiProcessing();
        await _receipts.AddAsync(receipt, ct);

        // RabbitMQ'ya AI analiz isteği gönder (async — kullanıcı beklemez!)
        var analyzeMessage = new
        {
            receipt_id    = receipt.Id.ToString(),
            tenant_id     = tenantId.ToString(),
            department_id = departmentId.ToString(),
            ocr_result    = new
            {
                raw_text     = "",
                vendor_name  = req.VendorName,
                receipt_date = receiptDate.ToString("yyyy-MM-dd"),
                amount       = amount,
                tax_amount   = req.TaxAmount,
                tax_rate     = req.TaxRate,
                image_base64 = req.ImageBase64 // AI servisine base64 olarak gönder
            },
            callback_url = $"{callbackBaseUrl}/api/receipts/{receipt.Id}/fraud-callback",
        };

        await _publisher.PublishAsync(AI_QUEUE, analyzeMessage, ct);

        // Budget cache'ini geçersiz kıl
        var year = req.ReceiptDate?.Year ?? DateTime.UtcNow.Year;
        var month = req.ReceiptDate?.Month ?? DateTime.UtcNow.Month;
        await _cache.RemoveAsync($"budget:{departmentId}:{year}:{month}", ct);

        return ToResponse(receipt, "");
    }

    // ── Fraud Callback (AI Servisinden gelen sonuç) ──────────
    public async Task HandleFraudCallbackAsync(
        Guid tenantId,
        FraudCallbackRequest callback,
        CancellationToken ct = default)
    {
        var id = Guid.Parse(callback.ReceiptId);
        var receipt = await _receipts.GetByIdAsync(id, tenantId, ct)
            ?? throw new KeyNotFoundException($"Fiş bulunamadı: {id}");

        var risk = callback.RiskLevel.ToLowerInvariant() switch
        {
            "high"   => RiskLevel.High,
            "medium" => RiskLevel.Medium,
            "low"    => RiskLevel.Low,
            _        => RiskLevel.Pending,
        };

        var reasonsJson = JsonSerializer.Serialize(callback.RulesChecked);
        receipt.SetFraudResult(callback.FraudScore, risk, reasonsJson);

        await _receipts.UpdateAsync(receipt, ct);
    }

    // ── Fiş Onayla ──────────────────────────────────────────
    public async Task<ReceiptResponse> ApproveAsync(
        Guid receiptId, Guid tenantId, Guid approverId, string userRole, Guid approverDepartmentId,
        CancellationToken ct = default)
    {
        var receipt = await GetOrThrowAsync(receiptId, tenantId, ct);
        
        // IDOR (Insecure Direct Object Reference) Prevention:
        // Eğer kullanıcı bir 'manager' ise, sadece kendi departmanındaki fişleri onaylayabilir.
        if (userRole == "manager" && receipt.DepartmentId != approverDepartmentId)
        {
            throw new UnauthorizedAccessException("Sadece kendi departmanınıza ait fişleri onaylayabilirsiniz.");
        }

        receipt.Approve(approverId);
        await _receipts.UpdateAsync(receipt, ct);
        return ToResponse(receipt, "");
    }

    // ── Fiş Reddet ──────────────────────────────────────────
    public async Task<ReceiptResponse> RejectAsync(
        Guid receiptId, Guid tenantId, Guid approverId, string userRole, Guid approverDepartmentId, string reason,
        CancellationToken ct = default)
    {
        var receipt = await GetOrThrowAsync(receiptId, tenantId, ct);

        // IDOR Prevention
        if (userRole == "manager" && receipt.DepartmentId != approverDepartmentId)
        {
            throw new UnauthorizedAccessException("Sadece kendi departmanınıza ait fişleri reddedebilirsiniz.");
        }

        receipt.Reject(approverId, reason);
        await _receipts.UpdateAsync(receipt, ct);
        return ToResponse(receipt, "");
    }

    // ── Detay Görüntüleme (IDOR Korumalı) ────────────────────
    public async Task<ReceiptResponse> GetReceiptDetailAsync(
        Guid receiptId, Guid tenantId, Guid userId, string userRole, Guid userDepartmentId,
        CancellationToken ct = default)
    {
        var receipt = await GetOrThrowAsync(receiptId, tenantId, ct);

        // Kendi fişi mi?
        if (receipt.SubmittedBy == userId)
            return ToResponse(receipt, "");

        // Kendi fişi değilse, Manager kendi departmanını görebilir
        if (userRole == "manager" && receipt.DepartmentId == userDepartmentId)
            return ToResponse(receipt, "");

        // Finance ve Admin herkesi görebilir
        if (userRole is "finance" or "admin")
            return ToResponse(receipt, "");

        // Aksi halde erişim yasak
        throw new UnauthorizedAccessException("Bu fişi görüntüleme yetkiniz yok.");
    }

    // ── Listele ─────────────────────────────────────────────
    public async Task<ReceiptListResponse> GetUserReceiptsAsync(
        Guid userId, Guid tenantId, int page, int pageSize, CancellationToken ct = default)
    {
        var items = await _receipts.GetByUserAsync(userId, tenantId, page, pageSize, ct);
        return new ReceiptListResponse(
            Items:      items.Select(r => ToResponse(r, "")).ToList(),
            TotalCount: items.Count,
            Page:       page,
            PageSize:   pageSize
        );
    }

    public async Task<ReceiptListResponse> GetDepartmentReceiptsAsync(
        Guid departmentId, Guid tenantId, int page, int pageSize, CancellationToken ct = default)
    {
        var items = await _receipts.GetByDepartmentAsync(departmentId, tenantId, page, pageSize, ct);
        return new ReceiptListResponse(items.Select(r => ToResponse(r, "")).ToList(), items.Count, page, pageSize);
    }

    public async Task<IReadOnlyList<ReceiptResponse>> GetHighRiskAsync(
        Guid tenantId, int minScore = 60, CancellationToken ct = default)
    {
        var items = await _receipts.GetHighRiskAsync(tenantId, minScore, ct);
        return items.Select(r => ToResponse(r, "")).ToList();
    }

    // ── Muhasebe Export ─────────────────────────────────────
    public async Task<string> ExportApprovedReceiptsToCsvAsync(
        Guid tenantId, Guid departmentId, CancellationToken ct = default)
    {
        // 1000 kayda kadar getir (Gerçek senaryoda tarih aralığı eklenebilir)
        var items = await _receipts.GetByDepartmentAsync(departmentId, tenantId, 1, 1000, ct);
        
        // Sadece onaylanmış fişleri filtrele
        var exportItems = items.Where(r => r.Status == ReceiptStatus.Approved).ToList();

        var sb = new System.Text.StringBuilder();
        sb.AppendLine("Fis_No,Tarih,Satici,Kategori,Tutar,KDV,Risk,Durum");

        foreach (var r in exportItems)
        {
            var vendor = r.VendorName?.Replace(",", " ") ?? "Bilinmiyor";
            sb.AppendLine($"{r.Id},{r.ReceiptDate:yyyy-MM-dd},{vendor},{r.Category},{r.Amount},{r.TaxAmount},{r.RiskLevel},{r.Status}");
        }

        return sb.ToString();
    }

    // ── Bütçe Durumu (Redis cache'li) ────────────────────────
    public async Task<BudgetStatusResponse?> GetBudgetStatusAsync(
        Guid departmentId, Guid tenantId, int year, int month,
        string deptName, CancellationToken ct = default)
    {
        var cacheKey = $"budget:{departmentId}:{year}:{month}";
        var cached   = await _cache.GetAsync<BudgetStatusResponse>(cacheKey, ct);
        if (cached is not null) return cached;

        var limit = await _budgets.GetAsync(departmentId, year, month, ct);
        if (limit is null) return null;

        var spent = await _receipts.GetMonthlySpendAsync(departmentId, year, month, ct);
        var remaining = Math.Max(limit.LimitAmount - spent, 0);
        var status = new BudgetStatusResponse(
            DepartmentId:   departmentId,
            DepartmentName: deptName,
            LimitAmount:    limit.LimitAmount,
            SpentAmount:    spent,
            RemainingAmount:remaining,
            UsagePercent:   limit.LimitAmount > 0 ? Math.Round(spent / limit.LimitAmount * 100, 1) : 0,
            IsExceeded:     spent > limit.LimitAmount
        );

        await _cache.SetAsync(cacheKey, status, TimeSpan.FromMinutes(15), ct);
        return status;
    }

    // ── Helpers ─────────────────────────────────────────────
    private async Task<Receipt> GetOrThrowAsync(Guid id, Guid tenantId, CancellationToken ct)
    {
        return await _receipts.GetByIdAsync(id, tenantId, ct)
            ?? throw new KeyNotFoundException($"Fiş bulunamadı: {id}");
    }

    private static ReceiptResponse ToResponse(Receipt r, string submittedByName) => new(
        Id:             r.Id,
        Status:         r.Status.ToString(),
        RiskLevel:      r.RiskLevel.ToString(),
        FraudScore:     r.FraudScore,
        FraudReasons:   r.FraudReasons,
        Amount:         r.Amount,
        Category:       r.Category,
        VendorName:     r.VendorName,
        ReceiptDate:    r.ReceiptDate,
        SubmittedByName:submittedByName,
        SubmittedAt:    r.SubmittedAt
    );

    private bool IsValidImage(string base64String)
    {
        try
        {
            var bytes = Convert.FromBase64String(base64String);
            if (bytes.Length < 4) return false;

            // JPEG Magic Number: FF D8 FF
            if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;

            // PNG Magic Number: 89 50 4E 47
            if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;

            return false; // Başka format desteklenmiyor
        }
        catch
        {
            return false; // Hatalı base64 formatı
        }
    }
}
