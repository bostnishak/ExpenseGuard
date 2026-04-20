"""
Fraud Tespit Servisi
Kural tabanlı kontroller + OpenAI LLM analizi
Çıktı: 0-100 arası fraud skoru
"""
import os
import json
from datetime import datetime, date

import httpx
import structlog
from openai import AsyncOpenAI
from dotenv import load_dotenv

# Load .env from parent directory
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), '.env'))

from models.schemas import FraudAnalysisResult, FraudRule, OcrResult, RiskLevel

logger = structlog.get_logger()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

# Sektör ortalamaları (TRY) — gerçekte veritabanından alınır
SECTOR_AVERAGES = {
    "food":          350.0,
    "transport":     200.0,
    "accommodation": 3000.0,
    "fuel":          1500.0,
    "office":        500.0,
    "entertainment": 800.0,
    "other":         500.0,
}

# Risk skoru → aksiyon eşikleri
AUTO_APPROVE_THRESHOLD = 25
AUTO_REJECT_THRESHOLD  = 80


class FraudDetectionService:
    """
    Fraud tespiti:
    1. Kural tabanlı kontroller (hızlı, belirleyici)
    2. LLM destekli derin analiz (gerektiğinde)
    """

    def __init__(self):
        self.llm_client = AsyncOpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None

    # ──────────────────────────────────────────────
    # KURAL 1: Hafta sonu kontrolü
    # ──────────────────────────────────────────────
    def _check_weekend(self, receipt_date: str | None) -> FraudRule:
        if not receipt_date:
            return FraudRule(rule="WEEKEND_CHECK", message="Tarih bilgisi eksik", passed=True)
        try:
            d = datetime.strptime(receipt_date, "%Y-%m-%d").date()
            is_weekend = d.weekday() >= 5
            return FraudRule(
                rule="WEEKEND_CHECK",
                message=f"Fiş tarihi ({d.strftime('%d.%m.%Y')}) hafta {'sonu' if is_weekend else 'içi'}",
                passed=not is_weekend,
            )
        except ValueError:
            return FraudRule(rule="WEEKEND_CHECK", message="Tarih formatı geçersiz", passed=True)

    # ──────────────────────────────────────────────
    # KURAL 2: KDV matematiksel tutarlılık
    # ──────────────────────────────────────────────
    def _check_tax_consistency(self, ocr: OcrResult) -> FraudRule:
        if ocr.amount is None or ocr.tax_amount is None or ocr.tax_rate is None:
            return FraudRule(
                rule="TAX_CONSISTENCY",
                message="KDV veya tutar bilgisi eksik, doğrulama yapılamadı",
                passed=True,
            )
        # Beklenen KDV = toplam * oran / (100 + oran)
        expected_net = ocr.amount / (1 + ocr.tax_rate / 100)
        expected_tax = ocr.amount - expected_net
        diff_pct = abs(expected_tax - ocr.tax_amount) / max(ocr.amount, 1) * 100
        passed = diff_pct < 2.0  # %2 tolerans

        return FraudRule(
            rule="TAX_CONSISTENCY",
            message=(
                f"KDV doğrulaması: beklenen ~{expected_tax:.2f} TL, "
                f"fişte {ocr.tax_amount:.2f} TL — fark {diff_pct:.1f}%"
                + (" ✓" if passed else " — UYUMSUZ")
            ),
            passed=passed,
        )

    # ──────────────────────────────────────────────
    # KURAL 3: Sektör ortalaması karşılaştırması
    # ──────────────────────────────────────────────
    def _check_sector_average(self, ocr: OcrResult, category: str = "other") -> FraudRule:
        if ocr.amount is None:
            return FraudRule(rule="SECTOR_AVERAGE", message="Tutar bilgisi yok", passed=True)
        avg = SECTOR_AVERAGES.get(category, SECTOR_AVERAGES["other"])
        ratio = ocr.amount / avg
        passed = ratio <= 3.0  # Ortalama 3x üstü şüpheli

        return FraudRule(
            rule="SECTOR_AVERAGE",
            message=(
                f"Tutar {ocr.amount:.2f} TL, '{category}' kategori ortalaması {avg:.2f} TL "
                f"({ratio:.1f}x)" + (" ✓" if passed else " — ANORMAL")
            ),
            passed=passed,
        )

    # ──────────────────────────────────────────────
    # KURAL 4: Kopuk tarih (çok eski veya gelecekte)
    # ──────────────────────────────────────────────
    def _check_date_validity(self, receipt_date: str | None) -> FraudRule:
        if not receipt_date:
            return FraudRule(rule="DATE_VALIDITY", message="Tarih yok", passed=True)
        try:
            d = datetime.strptime(receipt_date, "%Y-%m-%d").date()
            today = date.today()
            days_diff = (today - d).days
            if days_diff < 0:
                return FraudRule(rule="DATE_VALIDITY", message="Fiş tarihi gelecekte!", passed=False)
            if days_diff > 90:
                return FraudRule(rule="DATE_VALIDITY", message=f"Fiş {days_diff} gün önce kesilmiş — çok eski", passed=False)
            return FraudRule(rule="DATE_VALIDITY", message=f"Tarih geçerli ({days_diff} gün önce)", passed=True)
        except ValueError:
            return FraudRule(rule="DATE_VALIDITY", message="Tarih formatı hatalı", passed=False)

    # ──────────────────────────────────────────────
    # LLM: OpenAI GPT-4o ile derin analiz
    # ──────────────────────────────────────────────
    async def _llm_analysis(self, ocr: OcrResult, rules: list[FraudRule]) -> str:
        if not self.llm_client:
            return "LLM analizi devre dışı (API anahtarı tanımlı değil)."

        failed_rules = [r for r in rules if not r.passed]
        prompt = f"""
Sen bir kurumsal gider denetçisisin. Aşağıdaki fiş verilerini ve kural kontrollerini inceleyerek
bu giderin şüpheli olup olmadığını Türkçe olarak değerlendir (2-3 cümle).

Fiş Bilgileri:
- Satıcı: {ocr.vendor_name or 'Bilinmiyor'}
- Tarih: {ocr.receipt_date or 'Bilinmiyor'}
- Tutar: {ocr.amount or 'Bilinmiyor'} TL
- KDV: {ocr.tax_amount or 'Bilinmiyor'} TL (%{ocr.tax_rate or '?'})

Başarısız Kurallar:
{json.dumps([r.model_dump() for r in failed_rules], ensure_ascii=False, indent=2)}

Değerlendirmeni kısa ve net yap.
""".strip()

        try:
            resp = await self.llm_client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=300,
                temperature=0.3,
            )
            return resp.choices[0].message.content.strip()
        except Exception as e:
            logger.warning("LLM analizi başarısız", error=str(e))
            return f"LLM analizi tamamlanamadı: {str(e)}"

    # ──────────────────────────────────────────────
    # ANA ANALİZ FONKSİYONU
    # ──────────────────────────────────────────────
    async def analyze(
        self,
        receipt_id: str,
        ocr: OcrResult,
        category: str = "other",
    ) -> FraudAnalysisResult:
        """Tüm kuralları çalıştır, skor hesapla, LLM varsa derin analiz yap."""
        rules: list[FraudRule] = [
            self._check_weekend(ocr.receipt_date),
            self._check_tax_consistency(ocr),
            self._check_sector_average(ocr, category),
            self._check_date_validity(ocr.receipt_date),
        ]

        # Her başarısız kural 25 puan ekler (max 100)
        failed_count = sum(1 for r in rules if not r.passed)
        base_score = min(failed_count * 25, 100)

        # Sektör ortalaması 5x üstüyse +15 bonus
        if ocr.amount and category in SECTOR_AVERAGES:
            if ocr.amount > SECTOR_AVERAGES[category] * 5:
                base_score = min(base_score + 15, 100)

        fraud_score = base_score

        # Risk seviyesi
        if fraud_score >= 60:
            risk_level = RiskLevel.HIGH
        elif fraud_score >= 30:
            risk_level = RiskLevel.MEDIUM
        else:
            risk_level = RiskLevel.LOW

        # LLM analizi (yalnızca riskli fişler için — token tasarrufu)
        llm_reasoning = None
        if fraud_score >= 30 and self.llm_client:
            llm_reasoning = await self._llm_analysis(ocr, rules)

        # Aksiyon önerisi
        if fraud_score <= AUTO_APPROVE_THRESHOLD:
            action = "auto_approve"
        elif fraud_score >= AUTO_REJECT_THRESHOLD:
            action = "auto_reject"
        else:
            action = "manual_review"

        logger.info(
            "Fraud analizi tamamlandı",
            receipt_id=receipt_id,
            score=fraud_score,
            risk=risk_level,
            action=action,
        )

        return FraudAnalysisResult(
            receipt_id=receipt_id,
            fraud_score=fraud_score,
            risk_level=risk_level,
            rules_checked=rules,
            llm_reasoning=llm_reasoning,
            recommended_action=action,
        )


# Singleton instance
fraud_service = FraudDetectionService()
