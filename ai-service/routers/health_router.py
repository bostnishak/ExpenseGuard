"""Health check ve OCR / Analyze router'ları."""
from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse

from models.schemas import OcrResult, AnalyzeRequest, FraudAnalysisResult
from services.ocr_service  import ocr_service
from services.fraud_service import fraud_service

# ── Health ──────────────────────────────────────────────────
router = APIRouter()


@router.get("/health", tags=["Health"])
async def health_check():
    return {"status": "healthy", "service": "expenseguard-ai"}
