"""Database query helpers."""

from sqlalchemy.orm import Session
from app.models import ImageView, Image, Artist


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
    artist: str | None = None,
    location: str | None = None,
    timeframe: str | None = None,
    limit: int = 50,
    offset: int = 0,
):
    """Query ImageView records using optional filters with pagination."""
    query = db.query(ImageView).join(Image)
    if image_id:
        query = query.filter(ImageView.image_id == image_id)
    if view:
        query = query.filter(ImageView.view == view)
    if artist:
        query = query.join(Artist).filter(Artist.name.ilike(f"%{artist}%"))
    if location:
        query = query.filter(Image.location_name.ilike(f"%{location}%"))
    if timeframe:
        query = query.filter(Image.timeframe.ilike(f"%{timeframe}%"))
        
    return query.offset(offset).limit(limit).all()
