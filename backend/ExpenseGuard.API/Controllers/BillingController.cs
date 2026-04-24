using Microsoft.AspNetCore.Mvc;
using Stripe;
using System.IO;
using ExpenseGuard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ExpenseGuard.API.Controllers;

[ApiController]
[Route("api/billing")]
public class BillingController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly string _webhookSecret = "whsec_mocked_for_phase1";

    public BillingController(AppDbContext db)
    {
        _db = db;
    }

    [HttpPost("webhook")]
    public async Task<IActionResult> Webhook(CancellationToken ct)
    {
        var json = await new StreamReader(HttpContext.Request.Body).ReadToEndAsync(ct);
        
        try
        {
            // Demo/Pilot modunda imza doğrulamasını atlıyoruz (mock) veya try/catch ile yakalıyoruz
            var stripeEvent = EventUtility.ParseEvent(json);

            // Örnek: checkout.session.completed
            if (stripeEvent.Type == Events.CheckoutSessionCompleted)
            {
                var session = stripeEvent.Data.Object as Stripe.Checkout.Session;
                if (session != null)
                {
                    // session.ClientReferenceId içinde TenantId sakladığımızı varsayalım
                    if (Guid.TryParse(session.ClientReferenceId, out var tenantId))
                    {
                        var tenant = await _db.Tenants.FirstOrDefaultAsync(t => t.Id == tenantId, ct);
                        if (tenant != null)
                        {
                            tenant.SubscriptionStatus = "active";
                            tenant.StripeCustomerId = session.CustomerId;
                            tenant.SubscriptionId = session.SubscriptionId;
                            _db.Tenants.Update(tenant);
                            await _db.SaveChangesAsync(ct);
                            Console.WriteLine($"[STRIPE] Tenant {tenant.Name} aboneliği aktifleştirildi.");
                        }
                    }
                }
            }

            return Ok();
        }
        catch (StripeException e)
        {
            Console.WriteLine($"[STRIPE ERROR] {e.Message}");
            return BadRequest();
        }
        catch (Exception e)
        {
            Console.WriteLine($"[STRIPE UNEXPECTED ERROR] {e.Message}");
            return StatusCode(500);
        }
    }
}
