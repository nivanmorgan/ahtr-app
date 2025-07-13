# app/main.py

from fastapi import FastAPI
from fastapi_cache import FastAPICache
from fastapi_cache.backends.inmemory import InMemoryBackend
from app.image_router import router as image_router
from app.db import init_db

app = FastAPI(
    title="AHTR Map Backend Service",
    description="Serves map images and metadata from S3 and PostgreSQL",
    version="0.1.0"
)

@app.on_event("startup")
async def startup_event():
    init_db()
    FastAPICache.init(InMemoryBackend())

app.include_router(image_router, prefix="/api")

@app.get("/")
def read_root():
    return {"message": "AHTR Map Service Operational"}
@app.get("/health")
def health_check():
    return {"status": "healthy"}

