"""Analyze Router — OCR sonucunu alır, fraud analizi yapar."""
from fastapi import APIRouter, HTTPException
from models.schemas import AnalyzeRequest, FraudAnalysisResult
from services.fraud_service import fraud_service

router = APIRouter()


@router.post("/receipt", response_model=FraudAnalysisResult)
async def analyze_receipt(request: AnalyzeRequest):
    """
    OCR verisi verildiğinde fraud analizi yap.
    Sonuç hem API response'u hem de callback_url'ye POST edilir.
    """
    try:
        result = await fraud_service.analyze(
            receipt_id=request.receipt_id,
            ocr=request.ocr_result,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analiz hatası: {str(e)}")
