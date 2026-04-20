"""
RabbitMQ Consumer — 'receipt.analyze' kuyruğunu dinler.
.NET API'den gelen fiş analiz isteklerini işler ve
sonucu callback URL'ye HTTP POST ile döndürür.
"""
import os
import json
import asyncio

import aio_pika
import httpx
import structlog

from models.schemas import AnalyzeRequest
from services.fraud_service import fraud_service

logger = structlog.get_logger()

RABBITMQ_URL        = os.getenv("RABBITMQ_URL", "amqp://guest:guest@rabbitmq:5672/")
INTERNAL_API_SECRET = os.getenv("INTERNAL_API_SECRET", "SuperSecretInternalToken_For_FraudCallback_123!")
QUEUE_NAME          = "receipt.analyze"
PREFETCH_COUNT      = 5   # Aynı anda max 5 fiş işle


async def process_message(message: aio_pika.IncomingMessage) -> None:
    """Tek bir kuyruktaki mesajı işle."""
    async with message.process(requeue=True):
        try:
            payload = json.loads(message.body.decode())
            request = AnalyzeRequest(**payload)

            logger.info("Fiş analiz isteği alındı", receipt_id=request.receipt_id)

            # Fraud analizi yap
            result = await fraud_service.analyze(
                receipt_id=request.receipt_id,
                ocr=request.ocr_result,
            )

            # .NET API'ye sonucu callback ile gönder
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    request.callback_url,
                    json=result.model_dump(),
                    headers={
                        "Content-Type": "application/json",
                        "X-Internal-Secret": INTERNAL_API_SECRET
                    },
                )
                response.raise_for_status()

            logger.info(
                "Callback başarıyla gönderildi",
                receipt_id=request.receipt_id,
                score=result.fraud_score,
                status_code=response.status_code,
            )

        except Exception as e:
            logger.error("Mesaj işleme hatası", error=str(e))
            raise  # requeue=True olduğu için tekrar kuyruğa alınır


async def start_consumer() -> None:
    """RabbitMQ bağlantısı kur ve kuyruğu dinlemeye başla."""
    retry_delay = 5

    while True:
        try:
            logger.info("RabbitMQ'ya bağlanılıyor...", url=RABBITMQ_URL)
            connection = await aio_pika.connect_robust(RABBITMQ_URL)

            async with connection:
                channel = await connection.channel()
                await channel.set_qos(prefetch_count=PREFETCH_COUNT)

                queue = await channel.declare_queue(
                    QUEUE_NAME,
                    durable=True,  # RabbitMQ yeniden başlasa da kuyruk kaybolmaz
                )

                logger.info("Kuyruk dinleniyor", queue=QUEUE_NAME)
                await queue.consume(process_message)

                # Consumer çalışmaya devam eder
                await asyncio.Future()

        except asyncio.CancelledError:
            logger.info("Consumer durduruldu")
            break
        except Exception as e:
            logger.error("RabbitMQ bağlantı hatası, yeniden denenecek",
                         error=str(e), delay=retry_delay)
            await asyncio.sleep(retry_delay)
            retry_delay = min(retry_delay * 2, 60)  # Exponential backoff (max 60s)
