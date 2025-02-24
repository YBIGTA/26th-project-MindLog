from pydantic import BaseModel
from typing import List, Optional
import uuid
from datetime import datetime

# ✅ 태그 응답 스키마
class TagResponse(BaseModel):
    id: uuid.UUID
    type: str
    tag_name: str

    class Config:
        orm_mode = True  # SQLAlchemy 모델 변환 지원

# ✅ 이미지 응답 스키마 (GPS 정보 포함)
class ImageResponse(BaseModel):
    id: uuid.UUID
    image_url: str
    latitude: Optional[float]  # 위도 (GPS 정보 없을 수 있음)
    longitude: Optional[float]  # 경도 (GPS 정보 없을 수 있음)

    class Config:
        orm_mode = True

# ✅ 다이어리 생성 요청 스키마
class DiaryCreate(BaseModel):
    date: datetime  # 날짜를 문자열이 아닌 datetime 객체로 변경
    image_urls: List[str]
    emotions: List[str]
    text: str

# ✅ 다이어리 응답 스키마 (태그 및 이미지 정보 포함)
class DiaryResponse(BaseModel):
    id: uuid.UUID
    date: datetime  # 날짜를 datetime으로 변경
    images: List[ImageResponse]  # ✅ 이미지 응답 추가 (GPS 포함)
    emotions: List[str]
    text: Optional[str]
    tags: List[TagResponse]  # 태그 리스트 추가
    created_at: datetime  # 생성 날짜

    class Config:
        orm_mode = True  # SQLAlchemy 모델 변환 지원
