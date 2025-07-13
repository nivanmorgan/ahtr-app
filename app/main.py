# app/main.py

from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator
from app.image_router import router as image_router
from app.db import init_db, engine
import logging
import boto3
import os
from sqlalchemy import text

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ahtr")

app = FastAPI(
    title="AHTR Map Backend Service",
    description="Serves map images and metadata from S3 and PostgreSQL",
    version="0.1.0"
)

@app.on_event("startup")
async def startup_event():
    init_db()
    Instrumentator().instrument(app).expose(app)
    logger.info("Application startup complete")

app.include_router(image_router, prefix="/api")

@app.get("/")
def read_root():
    return {"message": "AHTR Map Service Operational"}
@app.get("/health")
def health_check():
    db_ok = True
    s3_ok = True

    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as exc:
        logger.exception("Database connectivity check failed: %s", exc)
        db_ok = False

    s3_client = boto3.client("s3")
    bucket = os.getenv("S3_BUCKET_NAME")
    try:
        if bucket:
            s3_client.head_bucket(Bucket=bucket)
        else:
            raise ValueError("S3_BUCKET_NAME not set")
    except Exception as exc:
        logger.exception("S3 connectivity check failed: %s", exc)
        s3_ok = False

    overall = db_ok and s3_ok
    return {
        "database": db_ok,
        "s3": s3_ok,
        "status": "healthy" if overall else "unhealthy"
    }