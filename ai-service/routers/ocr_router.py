"""OCR Router — Fiş görselini alır, Vision+Tesseract pipeline ile yapısal veri döndürür."""
from fastapi import APIRouter, UploadFile, File, HTTPException
from models.schemas import OcrResult
from services.ocr_orchestrator import ocr_orchestrator

router = APIRouter()


@router.post("/receipt", response_model=OcrResult)
async def ocr_receipt(file: UploadFile = File(...)):
    """
    Fiş görselini yükle, AI-powered OCR ile yapısal veri çıkar.
    Pipeline: GPT-4 Vision (primary) → Tesseract (fallback)
    Desteklenen formatlar: JPEG, PNG, WEBP, TIFF
    """
    allowed = {"image/jpeg", "image/png", "image/webp", "image/tiff"}
    if file.content_type not in allowed:
        raise HTTPException(status_code=400, detail=f"Desteklenmeyen format: {file.content_type}")

    image_bytes = await file.read()
    if len(image_bytes) > 10 * 1024 * 1024:  # 10MB limit
        raise HTTPException(status_code=413, detail="Dosya boyutu 10MB'ı aşamaz")

    result = await ocr_orchestrator.process(image_bytes)
    return result


@router.post("/receipt-base64", response_model=OcrResult)
async def ocr_receipt_base64(payload: dict):
    """
    Base64 formatında fiş görseli gönder (mobil API uyumlu).
    Body: { "image_base64": "..." }
    """
    base64_data = payload.get("image_base64")
    if not base64_data:
        raise HTTPException(status_code=400, detail="image_base64 alanı zorunludur")

    result = await ocr_orchestrator.process_base64(base64_data)
    return result
