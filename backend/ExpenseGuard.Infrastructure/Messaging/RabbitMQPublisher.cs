using System.Text;
using System.Text.Json;
using RabbitMQ.Client;
using ExpenseGuard.Domain.Interfaces;
using Microsoft.Extensions.Logging;

namespace ExpenseGuard.Infrastructure.Messaging;

/// <summary>
/// RabbitMQ mesaj yayıncısı.
/// Her çağrıda bağlantı açıp kapatmak yerine IConnection singleton olarak DI'dan alınır.
/// </summary>
public class RabbitMQPublisher : IMessagePublisher, IDisposable
{
    private readonly IConnection _connection;
    private readonly ILogger<RabbitMQPublisher> _logger;
    private IChannel? _channel;

    private static readonly JsonSerializerOptions _jsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    public RabbitMQPublisher(IConnection connection, ILogger<RabbitMQPublisher> logger)
    {
        _connection = connection;
        _logger     = logger;
    }

    private async Task<IChannel> GetChannelAsync()
    {
        if (_channel is { IsOpen: true }) return _channel;
        _channel = await _connection.CreateChannelAsync();
        return _channel;
    }

    public async Task PublishAsync<T>(string queueName, T message, CancellationToken ct = default) where T : class
    {
        var channel = await GetChannelAsync();

        // Kalıcı kuyruk (RabbitMQ yeniden başlasa bile veri kaybolmaz)
        await channel.QueueDeclareAsync(
            queue:      queueName,
            durable:    true,
            exclusive:  false,
            autoDelete: false,
            arguments:  null,
            cancellationToken: ct
        );

        var body    = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message, _jsonOpts));
        var props   = new BasicProperties { Persistent = true };

        await channel.BasicPublishAsync(
            exchange:    string.Empty,
            routingKey:  queueName,
            mandatory:   false,
            basicProperties: props,
            body:        body,
            cancellationToken: ct
        );

        _logger.LogInformation("Mesaj yayınlandı: Queue={Queue}, Type={Type}", queueName, typeof(T).Name);
    }

    public void Dispose() => _channel?.Dispose();
}
