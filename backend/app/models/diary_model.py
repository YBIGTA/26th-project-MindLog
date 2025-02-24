from sqlalchemy import Column, String, ForeignKey, TIMESTAMP, Text, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base
import uuid


class Diary(Base):
    __tablename__ = "diary"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey(
        "users.id"), nullable=False)
    date = Column(TIMESTAMP, nullable=False)
    text = Column(Text, nullable=True)
    emotions = Column(String, nullable=True)  # 감정(emotions) 컬럼 추가
    # server_default 수정
    created_at = Column(TIMESTAMP, server_default=func.now())

    # 다이어리 -> 이미지 관계
    images = relationship("Image", back_populates="diary",
                          cascade="all, delete-orphan")

    @property
    def tags(self):
        """
        다이어리에 연결된 모든 이미지에서 태그를 집계하여 중복 없이 리턴합니다.
        """
        return list({image_tag.tag for image in self.images for image_tag in image.tags})


class Image(Base):
    __tablename__ = "image"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    diary_id = Column(UUID(as_uuid=True), ForeignKey(
        "diary.id", ondelete="CASCADE"), nullable=False)
    image_url = Column(String, nullable=False)
    latitude = Column(Float, nullable=True)  # ✅ 위도 추가
    longitude = Column(Float, nullable=True)  # ✅ 경도 추가

    # 이미지 -> 다이어리 관계
    diary = relationship("Diary", back_populates="images")
    # 이미지 -> 태그 매핑 관계
    tags = relationship("ImageTag", back_populates="image",
                        cascade="all, delete-orphan")


class Tag(Base):
    __tablename__ = "tag"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tag_name = Column(String, nullable=False,
                      unique=True)  # 컬럼명을 tag_name으로 유지
    type = Column(String, nullable=False)  # 태그 타입 ("인물", "장소", "지역")


class ImageTag(Base):
    __tablename__ = "image_tag"

    image_id = Column(UUID(as_uuid=True), ForeignKey(
        "image.id", ondelete="CASCADE"), primary_key=True)
    tag_id = Column(UUID(as_uuid=True), ForeignKey(
        "tag.id", ondelete="CASCADE"), primary_key=True)

    # 태그 매핑 관계
    image = relationship("Image", back_populates="tags")
    tag = relationship("Tag")
