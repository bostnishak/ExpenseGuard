using Microsoft.Extensions.Configuration;
using Stripe;
using ExpenseGuard.Domain.Entities;

namespace ExpenseGuard.Infrastructure.Billing;

public class BillingService
{
    private readonly string _secretKey;

    public BillingService(IConfiguration config)
    {
        _secretKey = config["Stripe:SecretKey"] ?? "sk_test_mock";
        StripeConfiguration.ApiKey = _secretKey;
    }

    /// <summary>
    /// Yeni bir tenant için Stripe üzerinde müşteri oluşturur.
    /// </summary>
    public async Task<string> CreateCustomerAsync(Tenant tenant, string adminEmail, CancellationToken ct = default)
    {
        // Geliştirme ortamında mock key varsa Stripe'a gitme
        if (_secretKey == "sk_test_mock")
        {
            return $"cus_mock_{Guid.NewGuid():N}";
        }

        var options = new CustomerCreateOptions
        {
            Email = adminEmail,
            Name = tenant.Name,
            Metadata = new Dictionary<string, string>
            {
                { "TenantId", tenant.Id.ToString() },
                { "Domain", tenant.Domain }
            }
        };

        var service = new CustomerService();
        var customer = await service.CreateAsync(options, cancellationToken: ct);

        return customer.Id;
    }

    /// <summary>
    /// Müşteriyi belirli bir abonelik planına atar.
    /// </summary>
    public async Task<string> CreateSubscriptionAsync(string customerId, string priceId, CancellationToken ct = default)
    {
        if (_secretKey == "sk_test_mock")
        {
            return $"sub_mock_{Guid.NewGuid():N}";
        }

        var options = new SubscriptionCreateOptions
        {
            Customer = customerId,
            Items = new List<SubscriptionItemOptions>
            {
                new SubscriptionItemOptions { Price = priceId }
            },
            TrialPeriodDays = 14, // 14 günlük deneme süresi
        };

        var service = new SubscriptionService();
        var subscription = await service.CreateAsync(options, cancellationToken: ct);

        return subscription.Id;
    }
}
