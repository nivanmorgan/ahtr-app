from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import RedirectResponse
import boto3
import os
import logging

logger = logging.getLogger("ahtr.image_router")
router = APIRouter()

s3_client = boto3.client("s3")
S3_BUCKET = os.getenv("S3_BUCKET_NAME")

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