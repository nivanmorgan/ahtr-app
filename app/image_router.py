from fastapi import APIRouter, HTTPException, Query, Depends
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from fastapi_cache.decorator import cache
import boto3
import os
import logging

from sqlalchemy.orm import Session
from app.db import get_db
from app.queries import get_image_metadata, search_images

logger = logging.getLogger("ahtr.image_router")
router = APIRouter()

s3_client = boto3.client("s3")
S3_BUCKET = os.getenv("S3_BUCKET_NAME")

from app.db import get_db
from app.queries import list_images

@router.get("/images")
@cache(expire=60)
def get_images(
    limit: int = Query(10, ge=1, le=100, description="Number of records to return"),
    offset: int = Query(0, ge=0, description="Number of records to skip"),
    db: Session = Depends(get_db),
):
    images = list_images(db, limit=limit, offset=offset)
    return [
        {
            "image_id": img.image_id,
            "artwork_id": img.artwork_id,
            "image_view": img.image_view,
        }
        for img in images
    ]

@router.get("/image")
def get_image(image_key: str = Query(..., description="S3 key or image ID")):
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
        raise HTTPException(status_code=404, detail=f"Image not found: {str(e)}")


@router.get("/images")
def list_images(
    image_id: str | None = Query(None, description="Filter by image ID"),
    artwork_id: str | None = Query(None, description="Filter by artwork ID"),
    image_view: str | None = Query(None, description="Filter by image view"),
    db: Session = Depends(get_db),
):
    """Return image metadata along with a pre-signed S3 URL."""
    if not S3_BUCKET:
        raise HTTPException(status_code=500, detail="S3 bucket not configured")

    images = search_images(db, image_id=image_id, artwork_id=artwork_id, image_view=image_view)

    results = []
    for img in images:
        try:
            url = s3_client.generate_presigned_url(
                ClientMethod="get_object",
                Params={"Bucket": S3_BUCKET, "Key": img.image_id},
                ExpiresIn=300,
            )
        except Exception:
            url = None

        metadata = {
            "image_id": img.image_id,
            "artwork_id": img.artwork_id,
            "image_view": img.image_view,
        }

        if img.artwork:
            metadata["artwork"] = {
                "title": img.artwork.title,
                "container_artwork_id": img.artwork.container_artwork_id,
                "creation_date_modifier": img.artwork.creation_date_modifier,
                "creation_start_date": img.artwork.creation_start_date,
                "creation_end_date": img.artwork.creation_end_date,
            }

        results.append({"metadata": metadata, "url": url})

    return results