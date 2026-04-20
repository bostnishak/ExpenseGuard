namespace ExpenseGuard.Domain.Enums;

public enum UserRole
{
    Employee  = 1,
    Manager   = 2,
    Finance   = 3,
    Admin     = 4
}

public enum ReceiptStatus
{
    Pending      = 0,
    AiProcessing = 1,
    Approved     = 2,
    Rejected     = 3,
    Flagged      = 4  // Bütçe aşımı veya yüksek risk — manuel inceleme bekliyor
}

public enum RiskLevel
{
    Pending = 0,
    Low     = 1,
    Medium  = 2,
    High    = 3
}
