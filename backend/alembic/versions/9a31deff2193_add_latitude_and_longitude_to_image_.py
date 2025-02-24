"""Add latitude and longitude to image table

Revision ID: 9a31deff2193
Revises: 4bc82018dc35
Create Date: 2025-02-24 11:21:56.081461

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "9a31deff2193"
down_revision = "4bc82018dc35"
branch_labels = None
depends_on = None

def upgrade() -> None:
    """위도(latitude)와 경도(longitude) 컬럼을 image 테이블에 추가"""
    op.add_column("image", sa.Column("latitude", sa.Float(), nullable=True))
    op.add_column("image", sa.Column("longitude", sa.Float(), nullable=True))

def downgrade() -> None:
    """다운그레이드 시 latitude, longitude 컬럼을 삭제"""
    op.drop_column("image", "latitude")
    op.drop_column("image", "longitude")

