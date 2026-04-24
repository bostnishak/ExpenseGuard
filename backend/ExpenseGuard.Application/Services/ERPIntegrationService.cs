using System;
using System.Threading;
using System.Threading.Tasks;
using ExpenseGuard.Domain.Entities;

namespace ExpenseGuard.Application.Services;

public interface IERPIntegrationService
{
    Task<bool> SyncReceiptAsync(Receipt receipt, Tenant tenant, CancellationToken ct = default);
}

public class LogoIntegrationService : IERPIntegrationService
{
    // Gerçekte HTTP Client ile Logo Rest API'sine bağlanılır
    public async Task<bool> SyncReceiptAsync(Receipt receipt, Tenant tenant, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(tenant.ErpApiKey) || tenant.ErpProvider?.ToLower() != "logo")
        {
            return false;
        }

        // Mock: Logo ERP'ye veri gönderimi simülasyonu
        var payload = new
        {
            FicheNo = receipt.Id.ToString(),
            Date = receipt.ReceiptDate.ToString("yyyy-MM-dd"),
            TotalAmount = receipt.AmountTry,
            Description = $"Masraf Fişi - {receipt.VendorName} - {receipt.Category}"
        };

        // Simüle edilmiş bekleme süresi
        await Task.Delay(500, ct);

        // Başarılı senkronizasyon varsayalım
        return true;
    }
}
