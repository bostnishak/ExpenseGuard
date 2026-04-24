using System;
using System.Threading;
using System.Threading.Tasks;
using ExpenseGuard.Domain.Interfaces;

namespace ExpenseGuard.Application.Services;

public interface IDataAnonymizationService
{
    Task<bool> AnonymizeUserAsync(Guid userId, Guid tenantId, CancellationToken ct = default);
}

public class DataAnonymizationService : IDataAnonymizationService
{
    private readonly IUserRepository _users;

    public DataAnonymizationService(IUserRepository users)
    {
        _users = users;
    }

    public async Task<bool> AnonymizeUserAsync(Guid userId, Guid tenantId, CancellationToken ct = default)
    {
        // 1. SOC 2 / GDPR (KVKK) Unutulma Hakkı (Right to be Forgotten)
        // Kişisel Verilerin (PII) anonimleştirilmesi işlemi
        
        var user = await _users.GetByIdAsync(userId, tenantId, ct);
        if (user == null) return false;

        // Rastgele bir identifier oluştur
        var anonymousId = Guid.NewGuid().ToString("N").Substring(0, 8);

        user.UpdateProfile(
            firstName: "Anonim",
            lastName: $"Kullanıcı_{anonymousId}"
        );
        
        // Şifre ve e-postayı geçersiz kıl.
        // Gerçekte UpdateProfile'ın e-postayı değiştirmesine izin vermek veya User entitesinde metot açmak gerekir
        // Örneğin: user.AnonymizeEmail($"user_{anonymousId}@anonymized.local");

        await _users.UpdateAsync(user, ct);

        // Not: Gerçek hayatta bu kişinin fişlerindeki (Receipt) "VendorName" eğer şahıs şirketiyse 
        // veya "Description" kısmında kişisel veri varsa AI yardımıyla maskelenmesi gerekebilir.
        // Şimdilik sadece User tablosunu anonimleştiriyoruz.

        return true;
    }
}
