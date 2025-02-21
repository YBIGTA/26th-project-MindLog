from pydantic import BaseModel
from typing import List
import uuid

# ✅ 태그 응답 스키마


class TagResponse(BaseModel):
    id: uuid.UUID
    type: str
    tag_name: str

    class Config:
        from_attributes = True

# ✅ 다이어리 생성 요청 스키마


class DiaryCreate(BaseModel):
    date: str
    image_urls: List[str]
    emotions: List[str]
    text: str

# ✅ 다이어리 응답 스키마 (태그 포함)


class DiaryResponse(BaseModel):
    id: uuid.UUID
    date: str
    image_urls: List[str]
    emotions: List[str]
    text: str
    tags: List[TagResponse]  # 태그 리스트 추가
    created_at: str

    class Config:
        from_attributes = True
