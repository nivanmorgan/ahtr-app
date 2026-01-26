"""add timeframe to images table

Revision ID: 0003
Revises: 0002
Create Date: 2026-01-25 03:50:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0003'
down_revision = '0002'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('images', sa.Column('timeframe', sa.String(), nullable=True))


def downgrade():
    op.drop_column('images', 'timeframe')
