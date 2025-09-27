from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db import get_db
from app.models import Artist, Image, ImageView


router = APIRouter()


@router.get("/db-stats")
def db_stats(
    limit: int = Query(5, ge=0, le=50, description="Number of sample joined rows to return"),
    db: Session = Depends(get_db),
):
    """Return simple DB stats for debugging: table counts, view distribution, and a small sample join.

    Note: This endpoint is intended for dev troubleshooting only.
    """
    try:
        counts = {
            "artists": db.query(func.count(Artist.id)).scalar() or 0,
            "images": db.query(func.count(Image.id)).scalar() or 0,
            "image_views": db.query(func.count(ImageView.id)).scalar() or 0,
        }

        # Distribution of views
        dist_rows = (
            db.query(ImageView.view, func.count(ImageView.id))
            .group_by(ImageView.view)
            .order_by(func.count(ImageView.id).desc())
            .all()
        )
        view_distribution = [
            {"view": v, "count": int(c or 0)} for (v, c) in dist_rows
        ]

        # Small sample of image titles with a view label
        sample_rows = (
            db.query(Image.title, ImageView.view)
            .join(ImageView, Image.id == ImageView.image_id)
            .limit(limit)
            .all()
        )
        sample = [
            {"title": title, "view": view} for (title, view) in sample_rows
        ]

        return {
            "counts": counts,
            "view_distribution": view_distribution,
            "sample": sample,
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"DB stats error: {exc}")

