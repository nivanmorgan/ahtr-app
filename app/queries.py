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
def search_images(
    db: Session,
    image_id: str | None = None,
    artwork_id: str | None = None,
    image_view: str | None = None,
):
    """Query ``ImageView`` records using optional filters."""
    query = db.query(ImageView)
    if image_id:
        query = query.filter(ImageView.image_id == image_id)
    if artwork_id:
        query = query.filter(ImageView.artwork_id == artwork_id)
    if image_view:
        query = query.filter(ImageView.image_view == image_view)
    return query.all()
