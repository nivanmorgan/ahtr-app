# app/db.py

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os


def _build_db_url_from_env() -> str | None:
    host = os.getenv("DB_HOST")
    name = os.getenv("DB_NAME")
    user = os.getenv("DB_USER")
    password = os.getenv("DB_PASSWORD")
    if all([host, name, user, password]):
        return f"postgresql://{user}:{password}@{host}:5432/{name}"
    return None


POSTGRES_URL = os.getenv("POSTGRES_URL") or _build_db_url_from_env() or "postgresql://user:pass@localhost:5432/ahtr"

engine = create_engine(POSTGRES_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def init_db():
    # Import models so that metadata is populated before creating tables
    from app.models import Artist, Image, ImageView  # noqa: F401

    Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
