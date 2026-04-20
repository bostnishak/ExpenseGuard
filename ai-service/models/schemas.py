"""Pydantic modelleri — AI servisi request/response şemaları."""
from __future__ import annotations
from enum import Enum
from typing import Any
from pydantic import BaseModel, Field


class RiskLevel(str, Enum):
    LOW    = "low"
    MEDIUM = "medium"
    HIGH   = "high"


class OcrResult(BaseModel):
    raw_text:     str
    vendor_name:  str | None = None
    receipt_date: str | None = None   # ISO 8601 "YYYY-MM-DD"
    amount:       float | None = None
    tax_amount:   float | None = None
    tax_rate:     float | None = None  # %


class FraudRule(BaseModel):
    rule:    str
    message: str
    passed:  bool


class FraudAnalysisResult(BaseModel):
    receipt_id:    str
    fraud_score:   int = Field(ge=0, le=100)
    risk_level:    RiskLevel
    rules_checked: list[FraudRule]
    llm_reasoning: str | None = None
    recommended_action: str   # "auto_approve" | "auto_reject" | "manual_review"


class AnalyzeRequest(BaseModel):
    receipt_id:    str
    tenant_id:     str
    department_id: str
    ocr_result:    OcrResult
    callback_url:  str  # .NET API'ye sonucu gönderecek endpoint
