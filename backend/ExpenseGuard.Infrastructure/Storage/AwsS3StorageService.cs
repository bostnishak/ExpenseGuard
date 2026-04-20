using Amazon.S3;
using Amazon.S3.Transfer;
using ExpenseGuard.Domain.Interfaces;
using Microsoft.Extensions.Configuration;

namespace ExpenseGuard.Infrastructure.Storage;

public class AwsS3StorageService : IStorageService
{
    private readonly IAmazonS3 _s3Client;
    private readonly string _bucketName;

    public AwsS3StorageService(IConfiguration config)
    {
        // Geliştirme ortamında (AWS credentials yokken) uygulamanın çökmesini engellemek için mock fallback
        var accessKey = config["AWS:AccessKey"] ?? "mock-key";
        var secretKey = config["AWS:SecretKey"] ?? "mock-secret";
        _bucketName   = config["AWS:BucketName"] ?? "expenseguard-receipts-mock";

        var s3Config = new AmazonS3Config
        {
            RegionEndpoint = Amazon.RegionEndpoint.EUCentral1 // Frankfurt
        };
        
        // Sadece development ortamında AWS kullanmıyorsanız diye Basic credentials atıyoruz
        _s3Client = new AmazonS3Client(accessKey, secretKey, s3Config);
    }

    public async Task<string> UploadFileAsync(string fileName, string base64Content, string contentType, CancellationToken ct = default)
    {
        // Eğer Mock ayarlar devredeyse konsola log bas ve sahte URL dön
        if (_bucketName.EndsWith("-mock"))
        {
            var mockUrl = $"https://{_bucketName}.s3.eu-central-1.amazonaws.com/{fileName}";
            Console.WriteLine($"[MOCK S3 UPLOAD] Dosya {mockUrl} adresine yüklendi simülasyonu yapıldı.");
            return mockUrl;
        }

        try
        {
            var bytes = Convert.FromBase64String(base64Content);
            using var stream = new MemoryStream(bytes);

            var uploadRequest = new TransferUtilityUploadRequest
            {
                InputStream = stream,
                Key = fileName,
                BucketName = _bucketName,
                ContentType = contentType
            };

            var fileTransferUtility = new TransferUtility(_s3Client);
            await fileTransferUtility.UploadAsync(uploadRequest, ct);

            return $"https://{_bucketName}.s3.eu-central-1.amazonaws.com/{fileName}";
        }
        catch (Exception ex)
        {
            Console.WriteLine($"S3 Upload Hatası: {ex.Message}");
            throw new Exception("Dosya S3'e yüklenirken bir hata oluştu.", ex);
        }
    }
}
