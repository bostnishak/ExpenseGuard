using System;
using System.Threading;
using System.Threading.Tasks;
using ExpenseGuard.Domain.Entities;

namespace ExpenseGuard.Application.Services;

public interface INotificationService
{
    Task SendPushNotificationAsync(Guid userId, Guid tenantId, string title, string message, CancellationToken ct = default);
}

public class NotificationService : INotificationService
{
    public async Task SendPushNotificationAsync(Guid userId, Guid tenantId, string title, string message, CancellationToken ct = default)
    {
        // 1. Veritabanına kaydet (Notifications tablosu)
        var notification = new Notification
        {
            UserId = userId,
            TenantId = tenantId,
            Title = title,
            Message = message
        };

        // TODO: DbContext veya Repository üzerinden kaydet.
        // await _notifications.AddAsync(notification, ct);

        // 2. FCM (Firebase Cloud Messaging) API'sini çağır.
        // Mock: Task.Delay ile simüle ediyoruz
        await Task.Delay(100, ct);

        Console.WriteLine($"[FCM PUSH] To: {userId} | {title} - {message}");
    }
}
