"""add geographic coordinates to images table

Revision ID: 0002
Revises: 0001
Create Date: 2025-11-08 00:59:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None


def upgrade():
    # Add latitude column
    op.add_column('images', sa.Column('latitude', sa.Numeric(precision=10, scale=8), nullable=True))
    
    # Add longitude column
    op.add_column('images', sa.Column('longitude', sa.Numeric(precision=11, scale=8), nullable=True))
    
    # Add location_name column
    op.add_column('images', sa.Column('location_name', sa.String(length=255), nullable=True))


def downgrade():
    # Remove columns in reverse order
    op.drop_column('images', 'location_name')
    op.drop_column('images', 'longitude')
    op.drop_column('images', 'latitude')
