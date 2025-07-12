# app/models.py

from sqlalchemy import Column, String, Text, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid

from app.db import Base

class Artwork(Base):
    __tablename__ = "artworks"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    artwork_id = Column(String, unique=True, index=True)
    title = Column(Text)
    container_artwork_id = Column(String)
    creation_date_modifier = Column(String)
    creation_start_date = Column(String)
    creation_end_date = Column(String)

    images = relationship("ImageView", back_populates="artwork")

class ImageView(Base):
    __tablename__ = "image_views"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    image_id = Column(String, unique=True, index=True)
    artwork_id = Column(String, ForeignKey("artworks.artwork_id"))
    image_view = Column(String)

    artwork = relationship("Artwork", back_populates="images")
