using System;
using System.Threading;
using System.Threading.Tasks;
using Xunit;
using Moq;
using ExpenseGuard.Application.Services;
using ExpenseGuard.Domain.Entities;
using ExpenseGuard.Domain.Interfaces;
using ExpenseGuard.Application.DTOs;

namespace ExpenseGuard.Tests;

public class ReceiptServiceTests
{
    [Fact]
    public async Task CreateAsync_ValidRequest_ReturnsReceiptResponse()
    {
        // Arrange
        var mockReceiptRepo = new Mock<IReceiptRepository>();
        var mockBudgetRepo = new Mock<IBudgetRepository>();
        var mockCache = new Mock<ICacheService>();
        var mockPublisher = new Mock<IMessagePublisher>();
        var mockEncryption = new Mock<IEncryptionService>();
        var mockStorage = new Mock<IStorageService>();
        var mockEmail = new Mock<IEmailService>();
        var mockUsers = new Mock<IUserRepository>();
        var mockTax = new Mock<ITaxVerificationService>();
        var mockExchangeRate = new Mock<IExchangeRateService>();
        var mockErp = new Mock<IERPIntegrationService>();
        var mockNotification = new Mock<INotificationService>();

        mockExchangeRate.Setup(x => x.GetExchangeRateAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(1.0m);

        var service = new ReceiptService(
            mockReceiptRepo.Object,
            mockBudgetRepo.Object,
            mockCache.Object,
            mockPublisher.Object,
            mockEncryption.Object,
            mockStorage.Object,
            mockEmail.Object,
            mockUsers.Object,
            mockTax.Object,
            mockExchangeRate.Object,
            mockErp.Object,
            mockNotification.Object
        );

        var request = new CreateReceiptRequest
        {
            Amount = 100,
            VendorName = "Test Vendor",
            Category = "food",
            Currency = "TRY"
        };

        // Act
        var response = await service.CreateAsync(request, Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "http://localhost");

        // Assert
        Assert.NotNull(response);
        Assert.Equal(100, response.Amount);
        Assert.Equal("TRY", response.Currency);
        mockReceiptRepo.Verify(r => r.AddAsync(It.IsAny<Receipt>(), It.IsAny<CancellationToken>()), Times.Once);
        mockPublisher.Verify(p => p.PublishAsync(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<CancellationToken>()), Times.Once);
    }
}
