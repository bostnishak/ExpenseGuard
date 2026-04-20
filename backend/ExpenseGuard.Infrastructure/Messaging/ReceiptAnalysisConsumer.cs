using Microsoft.Extensions.Logging;
using RabbitMQ.Client;

namespace ExpenseGuard.Infrastructure.Messaging;

/// <summary>
/// RabbitMQ consumer — RabbitMQ.Client 7.x ile uyumlu.
/// </summary>
public class ReceiptAnalysisConsumer : IAsyncDisposable
{
    private readonly IConnection _connection;
    private readonly IChannel    _channel;
    private readonly ILogger<ReceiptAnalysisConsumer> _logger;
    private const string QueueName = "receipt.analyze.completed";

    private ReceiptAnalysisConsumer(IConnection connection, IChannel channel,
        ILogger<ReceiptAnalysisConsumer> logger)
    {
        _connection = connection;
        _channel    = channel;
        _logger     = logger;
    }

    public static async Task<ReceiptAnalysisConsumer> CreateAsync(
        IConnection connection,
        ILogger<ReceiptAnalysisConsumer> logger,
        CancellationToken ct = default)
    {
        var channel = await connection.CreateChannelAsync(cancellationToken: ct);
        await channel.QueueDeclareAsync(
            queue: QueueName, durable: true, exclusive: false,
            autoDelete: false, arguments: null, cancellationToken: ct);

        return new ReceiptAnalysisConsumer(connection, channel, logger);
    }

    public async Task StartConsumingAsync(
        Func<string, CancellationToken, Task> messageHandler,
        CancellationToken ct = default)
    {
        var consumer = new MessageConsumer(_channel, messageHandler, _logger);

        await _channel.BasicConsumeAsync(
            queue:    QueueName,
            autoAck:  false,
            consumer: consumer,
            cancellationToken: ct);

        _logger.LogInformation("RabbitMQ consumer başlatıldı: {Queue}", QueueName);
    }

    public async ValueTask DisposeAsync()
    {
        await _channel.CloseAsync();
        _channel.Dispose();
    }

    // ── Inner consumer class ──────────────────────────────────
    private sealed class MessageConsumer : AsyncDefaultBasicConsumer
    {
        private readonly Func<string, CancellationToken, Task> _handler;
        private readonly ILogger _logger;

        public MessageConsumer(
            IChannel channel,
            Func<string, CancellationToken, Task> handler,
            ILogger logger) : base(channel)
        {
            _handler = handler;
            _logger  = logger;
        }

        public override async Task HandleBasicDeliverAsync(
            string consumerTag, ulong deliveryTag, bool redelivered,
            string exchange, string routingKey,
            IReadOnlyBasicProperties properties, ReadOnlyMemory<byte> body,
            CancellationToken ct = default)
        {
            var message = System.Text.Encoding.UTF8.GetString(body.Span);
            try
            {
                await _handler(message, ct);
                await Channel.BasicAckAsync(deliveryTag, false, ct);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Mesaj işleme hatası");
                await Channel.BasicNackAsync(deliveryTag, false, true, ct);
            }
        }
    }
}
