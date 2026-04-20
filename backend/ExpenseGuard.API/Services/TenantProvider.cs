using ExpenseGuard.Domain.Interfaces;
using Microsoft.AspNetCore.Http;

namespace ExpenseGuard.API.Services;

public class TenantProvider : ITenantProvider
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public TenantProvider(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public Guid GetTenantId()
    {
        var context = _httpContextAccessor.HttpContext;
        if (context == null)
            return Guid.Empty; // Arka plan işlerinde vs. boş dönebilir

        if (context.Items.TryGetValue("TenantId", out var tenantIdObj) && tenantIdObj is Guid tenantId)
        {
            return tenantId;
        }

        return Guid.Empty;
    }
}
