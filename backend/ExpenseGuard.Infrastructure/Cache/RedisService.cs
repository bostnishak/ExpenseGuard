using System.Text.Json;
using Microsoft.Extensions.Caching.Distributed;
using ExpenseGuard.Domain.Interfaces;

namespace ExpenseGuard.Infrastructure.Cache;

/// <summary>Redis önbellek servisi. IDistributedCache üzerinden çalışır.</summary>
public class RedisService : ICacheService
{
    private readonly IDistributedCache _cache;
    private static readonly JsonSerializerOptions _jsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    public RedisService(IDistributedCache cache) => _cache = cache;

    public async Task<T?> GetAsync<T>(string key, CancellationToken ct = default) where T : class
    {
        var bytes = await _cache.GetAsync(key, ct);
        if (bytes is null || bytes.Length == 0) return null;

        return JsonSerializer.Deserialize<T>(bytes, _jsonOpts);
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan? expiry = null, CancellationToken ct = default) where T : class
    {
        var bytes = JsonSerializer.SerializeToUtf8Bytes(value, _jsonOpts);
        var opts  = new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = expiry ?? TimeSpan.FromMinutes(30),
        };
        await _cache.SetAsync(key, bytes, opts, ct);
    }

    public async Task RemoveAsync(string key, CancellationToken ct = default) =>
        await _cache.RemoveAsync(key, ct);
}
