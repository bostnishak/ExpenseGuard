using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;
using ExpenseGuard.Domain.Interfaces;

namespace ExpenseGuard.Infrastructure.Security;

/// <summary>
/// AES-256-GCM şifreleme — hassas finansal veriler için.
/// Always Encrypted benzeri koruma sağlar.
/// </summary>
public class EncryptionService : IEncryptionService
{
    private readonly byte[] _key;

    public EncryptionService(IConfiguration config)
    {
        var keyStr = config["Encryption:Key"]
            ?? throw new InvalidOperationException("Encryption:Key yapılandırması eksik!");

        // 256-bit (32 byte) key — SHA-256 ile normalize edilir
        _key = SHA256.HashData(Encoding.UTF8.GetBytes(keyStr));
    }

    public string Encrypt(string plainText)
    {
        var plainBytes = Encoding.UTF8.GetBytes(plainText);
        var encryptedBytes = EncryptCore(plainBytes);
        return Convert.ToBase64String(encryptedBytes);
    }

    public string Decrypt(string cipherText)
    {
        var cipherBytes = Convert.FromBase64String(cipherText);
        var plainBytes = DecryptCore(cipherBytes);
        return Encoding.UTF8.GetString(plainBytes);
    }

    public byte[] EncryptBytes(decimal value)
    {
        var plainBytes = Encoding.UTF8.GetBytes(value.ToString("G"));
        return EncryptCore(plainBytes);
    }

    public decimal DecryptToDecimal(byte[] data)
    {
        var plainBytes = DecryptCore(data);
        var str = Encoding.UTF8.GetString(plainBytes);
        return decimal.Parse(str);
    }

    // ── Core AES-GCM ────────────────────────────────────────
    private byte[] EncryptCore(byte[] plainBytes)
    {
        var nonce      = new byte[AesGcm.NonceByteSizes.MaxSize]; // 12 bytes
        var tag        = new byte[AesGcm.TagByteSizes.MaxSize];   // 16 bytes
        var cipherBytes = new byte[plainBytes.Length];

        RandomNumberGenerator.Fill(nonce);

        using var aes = new AesGcm(_key, AesGcm.TagByteSizes.MaxSize);
        aes.Encrypt(nonce, plainBytes, cipherBytes, tag);

        // Format: nonce (12) + tag (16) + ciphertext
        var result = new byte[nonce.Length + tag.Length + cipherBytes.Length];
        nonce.CopyTo(result, 0);
        tag.CopyTo(result, nonce.Length);
        cipherBytes.CopyTo(result, nonce.Length + tag.Length);
        return result;
    }

    private byte[] DecryptCore(byte[] data)
    {
        var nonce       = data[..12];
        var tag         = data[12..28];
        var cipherBytes = data[28..];
        var plainBytes  = new byte[cipherBytes.Length];

        using var aes = new AesGcm(_key, AesGcm.TagByteSizes.MaxSize);
        aes.Decrypt(nonce, cipherBytes, tag, plainBytes);
        return plainBytes;
    }
}
