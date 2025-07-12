# app/queries.py

from sqlalchemy.orm import Session
from app.models import ImageView

def get_image_metadata(db: Session, image_id: str):
    return db.query(ImageView).filter(ImageView.image_id == image_id).first()
