from fastapi import APIRouter, HTTPException, Query, Depends
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
import boto3
import os
import logging

from app.db import get_db
from app.queries import list_image_views, search_image_views


logger = logging.getLogger("ahtr.image_router")
router = APIRouter()

s3_client = boto3.client("s3")
S3_BUCKET = os.getenv("S3_BUCKET_NAME")


@router.get("/image")
def get_image(image_key: str = Query(..., description="S3 object key for the image")):
    if not S3_BUCKET:
        raise HTTPException(status_code=500, detail="S3 bucket not configured")

    try:
        url = s3_client.generate_presigned_url(
            ClientMethod="get_object",
            Params={"Bucket": S3_BUCKET, "Key": image_key},
            ExpiresIn=300,
        )
        logger.info("Generated presigned URL for %s", image_key)
        return RedirectResponse(url=url)
    except Exception as e:
        logger.exception("Failed to fetch image %s: %s", image_key, e)
        raise HTTPException(status_code=404, detail=f"Image not found: {str(e)}")


@router.get("/images")
def list_images(
    limit: int = Query(10, ge=1, le=100, description="Number of records to return"),
    offset: int = Query(0, ge=0, description="Number of records to skip"),
    image_id: str | None = Query(None, description="Filter by image UUID"),
    view: str | None = Query(None, description="Filter by view (e.g. 'front', 'back')"),
    db: Session = Depends(get_db),
):
    """Return ImageView rows; include a pre-signed S3 URL when possible."""
    if image_id or view:
        rows = search_image_views(db, image_id=image_id, view=view, limit=limit, offset=offset)
    else:
        rows = list_image_views(db, limit=limit, offset=offset)

    results = []
    for r in rows:
        url = None
        if S3_BUCKET and getattr(r, "image", None) and getattr(r.image, "s3_key", None):
            try:
                url = s3_client.generate_presigned_url(
                    ClientMethod="get_object",
                    Params={"Bucket": S3_BUCKET, "Key": r.image.s3_key},
                    ExpiresIn=300,
                )
            except Exception:
                url = None

        results.append({
            "id": str(r.id),
            "image_id": str(r.image_id) if r.image_id else None,
            "view": r.view,
            "url": url,
        })

    return results
