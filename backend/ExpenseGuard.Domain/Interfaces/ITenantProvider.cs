namespace ExpenseGuard.Domain.Interfaces;

public interface ITenantProvider
{
    Guid GetTenantId();
}
