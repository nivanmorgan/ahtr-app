"""initial migration

Revision ID: 0001
Revises: 
Create Date: 2025-07-13 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '0001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'artists',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('name', sa.String(), index=True),
        sa.Column('bio', sa.Text()),
    )
    op.create_table(
        'images',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('s3_key', sa.String(), unique=True),
        sa.Column('title', sa.Text()),
        sa.Column('artist_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('artists.id')),
    )
    op.create_table(
        'image_views',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('image_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('images.id')),
        sa.Column('view', sa.String()),
    )


def downgrade():
    op.drop_table('image_views')
    op.drop_table('images')
    op.drop_table('artists')
