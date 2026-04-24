"""
OCR Orchestrator — Vision (primary) + Tesseract (fallback) yönetimi.
GPT-4 Vision başarısız olursa otomatik olarak Tesseract'a düşer.
"""
import structlog

from models.schemas import OcrResult
from services.vision_ocr_service import vision_ocr_service
from services.ocr_service import ocr_service as tesseract_service

logger = structlog.get_logger()


class OCROrchestrator:
    """
    İki aşamalı OCR pipeline:
    1. GPT-4 Vision (yüksek doğruluk, ücretli)
    2. Tesseract (düşük doğruluk, ücretsiz — fallback)
    """

    async def process(self, image_bytes: bytes) -> OcrResult:
        """Fiş görselinden yapısal veri çıkar."""

        # ── 1. GPT-4 Vision ile dene ──────────────────────────
        if vision_ocr_service.available:
            try:
                result = await vision_ocr_service.process(image_bytes)

                # Sonuç yeterli mi kontrol et (en az tutar veya satıcı çıkmış olmalı)
                if result.amount is not None or result.vendor_name:
                    logger.info("OCR tamamlandı: Vision (primary)", method="vision")
                    return result

                logger.warning("Vision OCR sonucu yetersiz, Tesseract'a düşülüyor")
            except Exception as e:
                logger.warning("Vision OCR başarısız, Tesseract'a düşülüyor", error=str(e))

        # ── 2. Tesseract fallback ─────────────────────────────
        try:
            result = tesseract_service.process(image_bytes)
            logger.info("OCR tamamlandı: Tesseract (fallback)", method="tesseract")
            return result
        except Exception as e:
            logger.error("Tesseract OCR de başarısız", error=str(e))
            return OcrResult(raw_text=f"Her iki OCR motoru da başarısız: {str(e)}")

    async def process_base64(self, base64_image: str) -> OcrResult:
        """Base64 formatındaki görseli işle."""
        import base64 as b64_module
        try:
            image_bytes = b64_module.b64decode(base64_image)
            return await self.process(image_bytes)
        except Exception as e:
            logger.error("Base64 decode hatası", error=str(e))
            return OcrResult(raw_text=f"Base64 decode hatası: {str(e)}")


# Singleton instance
ocr_orchestrator = OCROrchestrator()
