using System;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using ExpenseGuard.Domain.Enums;
using ExpenseGuard.Domain.Interfaces;

namespace ExpenseGuard.Application.Services;

public interface IMLExportService
{
    Task<string> ExportForFineTuningAsync(Guid tenantId, CancellationToken ct = default);
}

public class MLExportService : IMLExportService
{
    private readonly IReceiptRepository _receipts;

    public MLExportService(IReceiptRepository receipts)
    {
        _receipts = receipts;
    }

    public async Task<string> ExportForFineTuningAsync(Guid tenantId, CancellationToken ct = default)
    {
        // 1. Sadece "Onaylanmış" (Doğru kabul edilen Ground Truth veriler) fişleri getir
        // Gerçekte pagination yapılır. Örnek amaçlı ilk 1000'i çekiyoruz.
        // IReceiptRepository'de GetApprovedReceiptsAsync metodu farz ediyoruz veya GetByDepartmentAsync filtrelemesi.
        // Repository pattern mock kullandığımız için boş bir liste ile simüle edeceğiz veya varolan methodu kullanacağız.
        
        var receipts = await _receipts.GetByDepartmentAsync(Guid.Empty, tenantId, 1, 1000, ct); 
        var approvedReceipts = receipts.Where(r => r.Status == ReceiptStatus.Approved).ToList();

        var sb = new StringBuilder();

        // JSONL (JSON Lines) Format for OpenAI Fine-Tuning
        // {"messages": [{"role": "system", "content": "..."}, {"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]}
        
        foreach (var receipt in approvedReceipts)
        {
            if (string.IsNullOrWhiteSpace(receipt.OcrRawText)) continue;

            var userContent = $"Lütfen fişi analiz et. OCR Metni:\n{receipt.OcrRawText}";
            var expectedAssistantContent = JsonSerializer.Serialize(new
            {
                vendor_name = receipt.VendorName,
                receipt_date = receipt.ReceiptDate.ToString("yyyy-MM-dd"),
                amount = receipt.Amount,
                tax_amount = receipt.TaxAmount,
                tax_rate = receipt.TaxRate,
                category = receipt.Category
            });

            var jsonlLine = new
            {
                messages = new[]
                {
                    new { role = "system", content = "Sen bir kurumsal masraf fişi veri çıkarma asistanısın. Çıktıların katı bir JSON olmalıdır." },
                    new { role = "user", content = userContent },
                    new { role = "assistant", content = expectedAssistantContent }
                }
            };

            sb.AppendLine(JsonSerializer.Serialize(jsonlLine, new JsonSerializerOptions { Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }));
        }

        return sb.ToString();
    }
}
