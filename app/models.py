from sqlalchemy import Column, String, Text, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid

from app.db import Base

class Artist(Base):
    __tablename__ = "artists"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, index=True)
    bio = Column(Text)

    images = relationship("Image", back_populates="artist")

class Image(Base):
    __tablename__ = "images"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    s3_key = Column(String, unique=True, index=True)
    title = Column(Text)
    artist_id = Column(UUID(as_uuid=True), ForeignKey("artists.id"))

    artist = relationship("Artist", back_populates="images")
    views = relationship("ImageView", back_populates="image")

class ImageView(Base):
    __tablename__ = "image_views"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    image_id = Column(UUID(as_uuid=True), ForeignKey("images.id"))
    view = Column(String)

    image = relationship("Image", back_populates="views")
