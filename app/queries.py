# app/queries.py

from sqlalchemy.orm import Session
from app.models import ImageView

def get_image_metadata(db: Session, image_id: str):
    return db.query(ImageView).filter(ImageView.image_id == image_id).first()

def list_images(db: Session, limit: int = 10, offset: int = 0):
    """Return a list of ImageView records with pagination."""
    return (
        db.query(ImageView)
        .offset(offset)
        .limit(limit)
        .all()
    )
