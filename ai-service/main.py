"""
ExpenseGuard Pro — Python FastAPI AI Mikroservisi
Görevler:
  1. OCR ile fişten metin çıkarma
  2. LLM + kural tabanlı fraud analizi
  3. RabbitMQ kuyruğunu dinleme (async consumer)
"""
import asyncio
import structlog
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import analyze_router, ocr_router, health_router
from services.rabbitmq_consumer import start_consumer

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Uygulama başlarken RabbitMQ consumer'ı başlat."""
    logger.info("AI mikroservisi başlatılıyor...")
    consumer_task = asyncio.create_task(start_consumer())
    yield
    logger.info("AI mikroservisi kapatılıyor...")
    consumer_task.cancel()
    try:
        await consumer_task
    except asyncio.CancelledError:
        pass


app = FastAPI(
    title="ExpenseGuard AI Service",
    description="OCR tabanlı fiş tarama ve LLM destekli fraud tespit servisi",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router.router)
app.include_router(ocr_router.router,     prefix="/ocr",     tags=["OCR"])
app.include_router(analyze_router.router, prefix="/analyze", tags=["Fraud Analysis"])
