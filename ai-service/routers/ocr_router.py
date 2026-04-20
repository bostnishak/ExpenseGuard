"""OCR Router — Fiş görselini alır, yapısal veri döndürür."""
from fastapi import APIRouter, UploadFile, File, HTTPException
from models.schemas import OcrResult
from services.ocr_service import ocr_service

router = APIRouter()


@router.post("/receipt", response_model=OcrResult)
async def ocr_receipt(file: UploadFile = File(...)):
    """
    Fiş görselini yükle, OCR ile yapısal veri çıkar.
    Desteklenen formatlar: JPEG, PNG, WEBP, TIFF
    """
    allowed = {"image/jpeg", "image/png", "image/webp", "image/tiff"}
    if file.content_type not in allowed:
        raise HTTPException(status_code=400, detail=f"Desteklenmeyen format: {file.content_type}")

    image_bytes = await file.read()
    if len(image_bytes) > 10 * 1024 * 1024:  # 10MB limit
        raise HTTPException(status_code=413, detail="Dosya boyutu 10MB'ı aşamaz")

    result = ocr_service.process(image_bytes)
    return result
