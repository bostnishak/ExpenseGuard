namespace ExpenseGuard.Domain.Interfaces;

public interface IStorageService
{
    Task<string> UploadFileAsync(string fileName, string base64Content, string contentType, CancellationToken ct = default);
}
