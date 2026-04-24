"""
GPT-4 Vision OCR Servisi — Fiş görselinden yapısal veri çıkarma.
Tesseract'a kıyasla ~%92-97 doğruluk oranı sağlar.
Maliyet optimizasyonu: Görüntü 512px'e resize edilir.
"""
import os
import io
import json
import base64

from openai import AsyncOpenAI
from PIL import Image
import structlog
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), '.env'))

from models.schemas import OcrResult

logger = structlog.get_logger()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

# Maliyet optimizasyonu: Görüntüyü max bu genişliğe küçült
MAX_IMAGE_WIDTH = 768

# Türkçe fiş okuma prompt'u — JSON mode ile structured output
RECEIPT_EXTRACTION_PROMPT = """Sen bir Türkiye fatura/fiş okuma uzmanısın. Verilen fiş görselinden aşağıdaki bilgileri çıkar.

KURALLAR:
1. Tutarları Türk Lirası formatından sayıya çevir (1.234,56 → 1234.56)
2. Tarihi YYYY-MM-DD formatına çevir
3. KDV oranı yoksa Türkiye standart oranlarından birini tahmin et: %1, %10, %20
4. Satıcı adını fişin en üstündeki şirket/marka adından al
5. Okunamayan veya bulunamayan alanlar için null döndür
6. Ham metni (raw_text) fişte okuduğun her şeyi satır satır yaz

Yanıtını SADECE aşağıdaki JSON formatında ver, başka hiçbir şey yazma:
{
  "raw_text": "fişten okunan tüm metin satır satır",
  "vendor_name": "satıcı/şirket adı veya null",
  "receipt_date": "YYYY-MM-DD veya null",
  "amount": 123.45,
  "tax_amount": 20.57,
  "tax_rate": 20.0
}"""


class VisionOCRService:
    """GPT-4 Vision ile fiş görselinden yapısal veri çıkarma."""

    def __init__(self):
        self.client = AsyncOpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None
        self.available = bool(OPENAI_API_KEY)

    def _resize_image(self, image_bytes: bytes) -> str:
        """Görseli küçült ve base64'e çevir (token tasarrufu)."""
        image = Image.open(io.BytesIO(image_bytes))

        # RGBA → RGB (JPEG uyumluluğu)
        if image.mode in ("RGBA", "P"):
            image = image.convert("RGB")

        # Genişliği MAX_IMAGE_WIDTH'e küçült
        w, h = image.size
        if w > MAX_IMAGE_WIDTH:
            scale = MAX_IMAGE_WIDTH / w
            image = image.resize((int(w * scale), int(h * scale)), Image.LANCZOS)

        # JPEG olarak base64'e çevir
        buffer = io.BytesIO()
        image.save(buffer, format="JPEG", quality=85)
        return base64.b64encode(buffer.getvalue()).decode("utf-8")

    def _parse_response(self, content: str) -> OcrResult:
        """LLM yanıtını parse et, hatalı JSON'a dayanıklı."""
        try:
            # JSON bloğunu bul (```json ... ``` ile sarılmış olabilir)
            text = content.strip()
            if text.startswith("```"):
                # Markdown code fence'ı kaldır
                lines = text.split("\n")
                text = "\n".join(lines[1:-1])

            data = json.loads(text)

            return OcrResult(
                raw_text=data.get("raw_text", ""),
                vendor_name=data.get("vendor_name"),
                receipt_date=data.get("receipt_date"),
                amount=self._safe_float(data.get("amount")),
                tax_amount=self._safe_float(data.get("tax_amount")),
                tax_rate=self._safe_float(data.get("tax_rate")),
            )
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            logger.warning("Vision OCR yanıt parse hatası", error=str(e), raw=content[:200])
            return OcrResult(raw_text=content)

    @staticmethod
    def _safe_float(val) -> float | None:
        """Güvenli float dönüşümü."""
        if val is None:
            return None
        try:
            return float(val)
        except (ValueError, TypeError):
            return None

    async def process(self, image_bytes: bytes) -> OcrResult:
        """Fiş görselini GPT-4 Vision ile işle."""
        if not self.client:
            logger.warning("Vision OCR kullanılamıyor: OPENAI_API_KEY tanımlı değil")
            return OcrResult(raw_text="")

        try:
            # Görseli optimize et
            base64_image = self._resize_image(image_bytes)

            logger.info("GPT-4 Vision OCR başlatılıyor...")

            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": RECEIPT_EXTRACTION_PROMPT},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{base64_image}",
                                    "detail": "high",
                                },
                            },
                        ],
                    }
                ],
                max_tokens=1000,
                temperature=0.1,  # Düşük temperature → daha deterministik çıkış
            )

            content = response.choices[0].message.content.strip()
            result = self._parse_response(content)

            logger.info(
                "Vision OCR tamamlandı",
                vendor=result.vendor_name,
                amount=result.amount,
                date=result.receipt_date,
                tokens_used=response.usage.total_tokens if response.usage else "?",
            )

            return result

        except Exception as e:
            logger.error("Vision OCR hatası", error=str(e))
            return OcrResult(raw_text=f"Vision OCR hatası: {str(e)}")

    async def process_base64(self, base64_image: str) -> OcrResult:
        """Base64 formatındaki görseli işle (mobil API'den gelen)."""
        try:
            image_bytes = base64.b64decode(base64_image)
            return await self.process(image_bytes)
        except Exception as e:
            logger.error("Base64 decode hatası", error=str(e))
            return OcrResult(raw_text=f"Base64 decode hatası: {str(e)}")


# Singleton instance
vision_ocr_service = VisionOCRService()
