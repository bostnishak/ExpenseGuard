using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace ExpenseGuard.Application.Services;

public interface ITaxVerificationService
{
    /// <summary>
    /// Verilen 10 haneli VKN'nin (Vergi Kimlik Numarası) geçerli olup olmadığını algoritma ile kontrol eder.
    /// Ardından e-Devlet API'sini (Mock) çağırarak şirketin gerçek durumunu döner.
    /// </summary>
    Task<TaxVerificationResult> VerifyTaxNumberAsync(string taxNumber, CancellationToken ct = default);
}

public class TaxVerificationResult
{
    public bool IsValid { get; set; }
    public string? CompanyName { get; set; }
    public string? Status { get; set; } // Active, Inactive
    public string? ErrorMessage { get; set; }
}

public class TaxVerificationService : ITaxVerificationService
{
    private readonly HttpClient _httpClient;

    public TaxVerificationService(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<TaxVerificationResult> VerifyTaxNumberAsync(string taxNumber, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(taxNumber) || taxNumber.Length != 10 || !long.TryParse(taxNumber, out _))
        {
            return new TaxVerificationResult { IsValid = false, ErrorMessage = "Vergi kimlik numarası 10 haneli rakamlardan oluşmalıdır." };
        }

        if (!IsVknAlgorithmValid(taxNumber))
        {
            return new TaxVerificationResult { IsValid = false, ErrorMessage = "Geçersiz VKN formatı." };
        }

        // Mock e-Devlet / GİB HTTP Çağrısı (Production'da gerçek entegrasyon yapılabilir)
        try
        {
            // var response = await _httpClient.GetAsync($"https://api.edevlet.mock/v1/vkn?number={taxNumber}", ct);
            // Simulate API Latency
            await Task.Delay(150, ct);

            // Mock responses based on the last digit
            int lastDigit = taxNumber[9] - '0';
            if (lastDigit % 10 == 9) // Mock logic: VKN ending in 9 is blacklisted/inactive
            {
                return new TaxVerificationResult
                {
                    IsValid = false,
                    Status = "Inactive",
                    ErrorMessage = "Sorgulanan firmanın mali kaydı pasif durumdadır."
                };
            }

            return new TaxVerificationResult
            {
                IsValid = true,
                CompanyName = "Örnek Teknoloji ve Tic. A.Ş.",
                Status = "Active"
            };
        }
        catch (Exception ex)
        {
            return new TaxVerificationResult { IsValid = false, ErrorMessage = $"VKN sorgulama servisine ulaşılamadı: {ex.Message}" };
        }
    }

    private bool IsVknAlgorithmValid(string vkn)
    {
        if (vkn.Length != 10) return false;

        int sum = 0;
        for (int i = 0; i < 9; i++)
        {
            int digit = vkn[i] - '0';
            int tmp = (digit + 10 - (i + 1)) % 10;
            if (tmp == 9)
            {
                sum += tmp;
            }
            else
            {
                int pow = (int)Math.Pow(2, 10 - (i + 1));
                sum += (tmp * pow) % 9;
            }
        }

        int lastDigit = (10 - (sum % 10)) % 10;
        return lastDigit == (vkn[9] - '0');
    }
}
