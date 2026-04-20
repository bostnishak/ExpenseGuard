# ── Build Stage ──────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Proje dosyalarını kopyala ve restore et (layer cache için)
COPY ExpenseGuard.Domain/ExpenseGuard.Domain.csproj         ExpenseGuard.Domain/
COPY ExpenseGuard.Application/ExpenseGuard.Application.csproj   ExpenseGuard.Application/
COPY ExpenseGuard.Infrastructure/ExpenseGuard.Infrastructure.csproj ExpenseGuard.Infrastructure/
COPY ExpenseGuard.API/ExpenseGuard.API.csproj               ExpenseGuard.API/

RUN dotnet restore ExpenseGuard.API/ExpenseGuard.API.csproj

# Kaynak kodları kopyala ve publish et
COPY . .
RUN dotnet publish ExpenseGuard.API/ExpenseGuard.API.csproj \
    -c Release -o /app/publish --no-restore

# ── Runtime Stage ─────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

# Güvenlik: root olmayan kullanıcı
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
RUN adduser --disabled-password --gecos "" appuser
USER appuser

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

EXPOSE 8080

ENTRYPOINT ["dotnet", "ExpenseGuard.API.dll"]
