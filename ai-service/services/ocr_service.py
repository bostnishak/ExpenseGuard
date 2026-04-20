"""
OCR Servisi — Tesseract ile fiş görselinden metin ve yapısal veri çıkarımı.
"""
import re
import io
from datetime import datetime

import pytesseract
from PIL import Image, ImageEnhance, ImageFilter
import structlog

from models.schemas import OcrResult

logger = structlog.get_logger()


class OCRService:
    """Görsel → metin → yapısal fiş verisi."""

    # Türkiye KDV oranları (%)
    VALID_TAX_RATES = {1, 10, 20}

    def preprocess_image(self, image: Image.Image) -> Image.Image:
        """Görüntüyü OCR doğruluğunu artırmak için ön işle."""
        # Gri tonlamaya çevir
        image = image.convert("L")
        # Keskinleştir
        image = image.filter(ImageFilter.SHARPEN)
        # Kontrastı artır
        enhancer = ImageEnhance.Contrast(image)
        image = enhancer.enhance(2.0)
        # Boyutu artır (küçük fişler için)
        w, h = image.size
        if w < 800:
            scale = 800 / w
            image = image.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
        return image

    def extract_text(self, image_bytes: bytes) -> str:
        """Ham görüntü byte'larından Tesseract ile metin çıkar."""
        try:
            image = Image.open(io.BytesIO(image_bytes))
            image = self.preprocess_image(image)
            # Türkçe + İngilizce dil paketi
            text = pytesseract.image_to_string(image, lang="tur+eng", config="--psm 6")
            logger.info("OCR tamamlandı", char_count=len(text))
            return text
        except Exception as e:
            logger.error("OCR hatası", error=str(e))
            return ""

    def parse_amount(self, text: str) -> float | None:
        """Metinden toplam tutarı çıkar. Örn: '245,90 TL', '1.200,50 TRY'"""
        patterns = [
            r"TOPLAM[:\s]*([0-9.,]+)\s*(?:TL|TRY|₺)",
            r"GENEL TOPLAM[:\s]*([0-9.,]+)",
            r"([0-9.,]+)\s*(?:TL|TRY|₺)\s*$",
        ]
        for pat in patterns:
            match = re.search(pat, text, re.IGNORECASE | re.MULTILINE)
            if match:
                raw = match.group(1).replace(".", "").replace(",", ".")
                try:
                    return float(raw)
                except ValueError:
                    continue
        return None

    def parse_tax_amount(self, text: str) -> tuple[float | None, float | None]:
        """KDV tutarı ve oranını çıkar."""
        amount_match = re.search(
            r"KDV\s*%?([0-9]+)?[:\s]*([0-9.,]+)\s*(?:TL|TRY|₺)?",
            text, re.IGNORECASE
        )
        rate = None
        amount = None
        if amount_match:
            if amount_match.group(1):
                rate = float(amount_match.group(1))
            raw = amount_match.group(2).replace(".", "").replace(",", ".")
            try:
                amount = float(raw)
            except ValueError:
                pass
        return amount, rate

    def parse_date(self, text: str) -> str | None:
        """Fiş tarihini çıkar. Çeşitli Türkiye formatını destekler."""
        patterns = [
            r"\b(\d{2})[/\-\.](\d{2})[/\-\.](\d{4})\b",  # 15/03/2024 veya 15-03-2024
            r"\b(\d{4})[/\-\.](\d{2})[/\-\.](\d{2})\b",  # 2024-03-15
        ]
        for pat in patterns:
            match = re.search(pat, text)
            if match:
                groups = match.groups()
                if len(groups[0]) == 2:
                    # DD/MM/YYYY → YYYY-MM-DD
                    return f"{groups[2]}-{groups[1]}-{groups[0]}"
                else:
                    # YYYY-MM-DD
                    return f"{groups[0]}-{groups[1]}-{groups[2]}"
        return None

    def parse_vendor(self, text: str) -> str | None:
        """Satıcı / Şirket adını çıkarmaya çalış (ilk 3 satırdan)."""
        lines = [l.strip() for l in text.split("\n") if l.strip()]
        # Genellikle fişlerin ilk 1-3 satırında şirket adı bulunur
        candidates = lines[:3]
        # Kısa, sayı içermeyen bir satır muhtemelen şirket adıdır
        for line in candidates:
            if len(line) > 3 and not re.search(r"\d{5,}", line):
                return line[:100]
        return None

    def process(self, image_bytes: bytes) -> OcrResult:
        """Tam OCR pipeline: görüntü → yapısal fiş verisi."""
        raw_text = self.extract_text(image_bytes)
        amount = self.parse_amount(raw_text)
        tax_amount, tax_rate = self.parse_tax_amount(raw_text)
        receipt_date = self.parse_date(raw_text)
        vendor_name = self.parse_vendor(raw_text)

        return OcrResult(
            raw_text=raw_text,
            vendor_name=vendor_name,
            receipt_date=receipt_date,
            amount=amount,
            tax_amount=tax_amount,
            tax_rate=tax_rate,
        )


# Singleton instance
ocr_service = OCRService()
