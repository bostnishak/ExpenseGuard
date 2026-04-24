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
    private readonly IEmailService      _email;
    private readonly IUserRepository    _users;
    private readonly ITaxVerificationService _taxService;
    private readonly IExchangeRateService _exchangeRateService;
    private readonly IERPIntegrationService _erpIntegration;
    private readonly INotificationService _notificationService;

    private const string AI_QUEUE = "receipt.analyze";

    public ReceiptService(
        IReceiptRepository receipts,
        IBudgetRepository  budgets,
        ICacheService      cache,
        IMessagePublisher  publisher,
        IEncryptionService encryption,
        IStorageService    storage,
        IEmailService      email,
        IUserRepository    users,
        ITaxVerificationService taxService,
        IExchangeRateService exchangeRateService,
        IERPIntegrationService erpIntegration,
        INotificationService notificationService)
    {
        _receipts   = receipts;
        _budgets    = budgets;
        _cache      = cache;
        _publisher  = publisher;
        _encryption = encryption;
        _storage    = storage;
        _email      = email;
        _users      = users;
        _taxService = taxService;
        _exchangeRateService = exchangeRateService;
        _erpIntegration = erpIntegration;
        _notificationService = notificationService;
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
            taxRate:      req.TaxRate,
            currency:     req.Currency ?? "TRY"
        );

        // Faz 3: Multi-Currency Exchange Rate Fetch
        var rate = await _exchangeRateService.GetExchangeRateAsync(receipt.Currency, ct);
        receipt.SetCurrencyData(rate, receipt.Amount * rate);

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

        // Faz 3: Yöneticilere mobil onay bildirimi (Push Notification)
        // Şimdilik işlemi yapan kullanıcının departman yöneticisi veya tenant admin'i bulup ona atılmalı
        // Biz simülasyon amaçlı admin user bulup yolluyoruz (Demo verisi)
        var adminUser = await _users.GetByIdAsync(userId, tenantId, ct); // Kendisine atıyoruz test için
        if (adminUser != null)
        {
            await _notificationService.SendPushNotificationAsync(
                userId, tenantId, 
                "Yeni Fiş Onaya Düştü", 
                $"{amount} {receipt.Currency} tutarında {receipt.VendorName ?? "yeni"} fiş incelenmeyi bekliyor.", 
                ct);
        }

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

        var reasons = new List<string>(callback.RulesChecked);
        int finalScore = callback.FraudScore;

        // Mükerrer Fiş Kontrolü (Duplicate Receipt)
        if (!string.IsNullOrEmpty(receipt.VendorName) && receipt.Amount > 0)
        {
            bool isDuplicate = await _receipts.IsDuplicateAsync(
                receipt.TenantId, receipt.VendorName, receipt.Amount, receipt.ReceiptDate, receipt.Id, ct);

            if (isDuplicate)
            {
                reasons.Add("DuplicateReceiptDetected");
                finalScore += 50;
                risk = RiskLevel.High;
                
                // Admin'e bildirim at (opsiyonel / async)
                var adminUser = await _users.GetByIdAsync(receipt.SubmittedBy, tenantId, ct); // Admin for tenant is better, but we'll email the submitter or an admin if we had GetAdmins. For now, email the submitter warning them.
                if (adminUser != null)
                {
                    string body = $"Merhaba {adminUser.FirstName},<br><br>{receipt.VendorName} firmasından alınan {receipt.Amount} {receipt.Currency} tutarındaki fiş mükerrer olarak tespit edilmiştir. Lütfen sistemi kontrol edin.";
                    await _email.SendEmailAsync(adminUser.Email, "Yüksek Riskli (Mükerrer) Fiş Tespit Edildi", body, ct);
                }
            }
        }

        // ── Faz 2: Gelişmiş Fraud Kontrolleri ───────────────────
        
        // 1. e-Devlet VKN Doğrulaması (Mock)
        var mockVkn = "1234567890"; // Gerçekte OCR'dan (receipt.TaxNumber) alınmalı
        var taxResult = await _taxService.VerifyTaxNumberAsync(mockVkn, ct);
        if (!taxResult.IsValid)
        {
            reasons.Add($"TaxVerificationFailed: {taxResult.ErrorMessage}");
            finalScore += 40;
            risk = RiskLevel.High;
        }

        // 2. Round-Number Kontrolü
        if (receipt.Amount > 0 && receipt.Amount % 100 == 0)
        {
            reasons.Add("RoundNumberDetected");
            finalScore += 20;
            if (risk == RiskLevel.Low) risk = RiskLevel.Medium;
        }

        // 3. Split Transaction & 4. Behavioral Baseline
        var userRecentReceipts = await _receipts.GetByUserAsync(receipt.SubmittedBy, tenantId, 1, 50, ct);
        
        var splitCount = userRecentReceipts.Count(r => 
            r.Id != receipt.Id && 
            r.VendorName == receipt.VendorName && 
            r.ReceiptDate == receipt.ReceiptDate);
            
        if (splitCount > 0)
        {
            reasons.Add("SplitTransactionDetected");
            finalScore += 30;
            risk = RiskLevel.High;
        }

        var avgAmount = userRecentReceipts.Where(r => r.Id != receipt.Id).Average(r => (decimal?)r.Amount) ?? 0;
        if (avgAmount > 0 && receipt.Amount > avgAmount * 3)
        {
            reasons.Add("BehavioralAnomaly");
            finalScore += 25;
            if (risk != RiskLevel.High) risk = RiskLevel.Medium;
        }

        var reasonsJson = JsonSerializer.Serialize(reasons);
        receipt.SetFraudResult(finalScore, risk, reasonsJson);

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

        // Kullanıcıya e-posta gönder
        var submitter = await _users.GetByIdAsync(receipt.SubmittedBy, tenantId, ct);
        if (submitter != null)
        {
            string body = $"Merhaba {submitter.FirstName},<br><br>{receipt.VendorName} firmasından {receipt.ReceiptDate:yyyy-MM-dd} tarihinde aldığınız {receipt.Amount} {receipt.Currency} tutarındaki gider fişi onaylanmıştır.<br><br>ExpenseGuard Ekibi";
            await _email.SendEmailAsync(submitter.Email, "Fişiniz Onaylandı", body, ct);
        }

        // ── Faz 3: ERP Senkronizasyonu (Logo / SAP vb.) ──
        // Mock tenant oluşturarak yolluyoruz. Normalde db'den alınır.
        var tenant = new Tenant { ErpProvider = "Logo", ErpApiKey = "dummy-key" }; 
        var syncResult = await _erpIntegration.SyncReceiptAsync(receipt, tenant, ct);
        if (syncResult)
        {
            receipt.MarkErpSynced();
            await _receipts.UpdateAsync(receipt, ct);
        }

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

        // Kullanıcıya e-posta gönder
        var submitter = await _users.GetByIdAsync(receipt.SubmittedBy, tenantId, ct);
        if (submitter != null)
        {
            string body = $"Merhaba {submitter.FirstName},<br><br>{receipt.VendorName} firmasından {receipt.ReceiptDate:yyyy-MM-dd} tarihinde aldığınız {receipt.Amount} {receipt.Currency} tutarındaki gider fişi aşağıdaki sebeple reddedilmiştir:<br><br><em>{reason}</em><br><br>Lütfen fişinizi düzeltip tekrar yükleyin.<br><br>ExpenseGuard Ekibi";
            await _email.SendEmailAsync(submitter.Email, "Fişiniz Reddedildi", body, ct);
        }

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

    public async Task<byte[]> ExportApprovedReceiptsToExcelAsync(
        Guid tenantId, Guid departmentId, CancellationToken ct = default)
    {
        var items = await _receipts.GetByDepartmentAsync(departmentId, tenantId, 1, 5000, ct);
        var exportItems = items.Where(r => r.Status == ReceiptStatus.Approved).ToList();

        using var workbook = new ClosedXML.Excel.XLWorkbook();
        var worksheet = workbook.Worksheets.Add("Onayli_Fisler");

        worksheet.Cell(1, 1).Value = "Fiş No";
        worksheet.Cell(1, 2).Value = "Tarih";
        worksheet.Cell(1, 3).Value = "Satıcı";
        worksheet.Cell(1, 4).Value = "Kategori";
        worksheet.Cell(1, 5).Value = "Tutar (TL)";
        worksheet.Cell(1, 6).Value = "KDV Tutarı";
        worksheet.Cell(1, 7).Value = "Risk Seviyesi";

        var headerRow = worksheet.Row(1);
        headerRow.Style.Font.Bold = true;
        headerRow.Style.Fill.BackgroundColor = ClosedXML.Excel.XLColor.LightGray;

        int row = 2;
        foreach (var r in exportItems)
        {
            worksheet.Cell(row, 1).Value = r.Id.ToString();
            worksheet.Cell(row, 2).Value = r.ReceiptDate.ToString("yyyy-MM-dd");
            worksheet.Cell(row, 3).Value = r.VendorName ?? "Bilinmiyor";
            worksheet.Cell(row, 4).Value = r.Category ?? "";
            worksheet.Cell(row, 5).Value = r.Amount;
            worksheet.Cell(row, 6).Value = r.TaxAmount ?? 0;
            worksheet.Cell(row, 7).Value = r.RiskLevel.ToString();
            row++;
        }

        worksheet.Columns().AdjustToContents();

        using var stream = new System.IO.MemoryStream();
        workbook.SaveAs(stream);
        return stream.ToArray();
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
