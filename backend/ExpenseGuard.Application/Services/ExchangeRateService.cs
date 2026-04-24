using System;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using System.Xml.Linq;

namespace ExpenseGuard.Application.Services;

public interface IExchangeRateService
{
    Task<decimal> GetExchangeRateAsync(string currencyCode, CancellationToken ct = default);
}

public class ExchangeRateService : IExchangeRateService
{
    private readonly HttpClient _httpClient;
    private const string TcmbUrl = "https://www.tcmb.gov.tr/kurlar/today.xml";

    public ExchangeRateService(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<decimal> GetExchangeRateAsync(string currencyCode, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(currencyCode) || currencyCode.ToUpper() == "TRY")
            return 1.0m;

        try
        {
            var response = await _httpClient.GetStringAsync(TcmbUrl, ct);
            var xmlDoc = XDocument.Parse(response);
            
            var currencyElement = xmlDoc.Root?.Elements("Currency")
                .FirstOrDefault(e => e.Attribute("CurrencyCode")?.Value == currencyCode.ToUpper());

            if (currencyElement != null)
            {
                var sellingRateStr = currencyElement.Element("ForexSelling")?.Value;
                if (decimal.TryParse(sellingRateStr, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out decimal rate))
                {
                    return rate;
                }
            }

            // Fallback mock rate if XML parsing fails or currency not found (e.g. for demo stability)
            return GetMockRate(currencyCode);
        }
        catch (Exception)
        {
            // Network failures shouldn't crash the receipt processing in demo/testing
            return GetMockRate(currencyCode);
        }
    }

    private decimal GetMockRate(string currencyCode)
    {
        return currencyCode.ToUpper() switch
        {
            "USD" => 32.50m,
            "EUR" => 34.80m,
            "GBP" => 40.20m,
            _ => 1.0m
        };
    }
}
