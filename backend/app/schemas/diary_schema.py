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

# ✅ 개별 장소 다이어리 응답 스키마
class PlaceDiaryResponse(BaseModel):
    id: uuid.UUID  # 다이어리 ID
    thumbnail_url: str  # 썸네일 이미지 (첫 번째 이미지)
    latitude: Optional[float]  # 위도
    longitude: Optional[float]  # 경도

    class Config:
        orm_mode = True

# ✅ 장소별 그룹 응답 스키마
class PlaceResponse(BaseModel):
    category: str  # 장소 태그 이름 (예: "도시", "산", "강가")
    diary_count: int  # 해당 장소 태그를 가진 다이어리 개수
    diaries: List[PlaceDiaryResponse]  # 다이어리 리스트 (썸네일 + 위치 포함)

    class Config:
        orm_mode = True