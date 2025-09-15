"""Database query helpers."""

from sqlalchemy.orm import Session
from app.models import ImageView


def list_image_views(db: Session, limit: int = 10, offset: int = 0):
    """Return ImageView records with pagination."""
    return (
        db.query(ImageView)
        .offset(offset)
        .limit(limit)
        .all()
    )


def search_image_views(
    db: Session,
    image_id: str | None = None,
    view: str | None = None,
    limit: int = 50,
    offset: int = 0,
):
    """Query ImageView records using optional filters with pagination."""
    query = db.query(ImageView)
    if image_id:
        query = query.filter(ImageView.image_id == image_id)
    if view:
        query = query.filter(ImageView.view == view)
    return query.offset(offset).limit(limit).all()
