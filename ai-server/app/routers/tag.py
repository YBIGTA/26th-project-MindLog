from fastapi import APIRouter, HTTPException
from app.models.place_tag import PlaceTagger
from app.models.location_tag import LocationTagger
from app.models.companion_tag import CompanionTagger
from typing import List, Dict
from pydantic import BaseModel, Field

router = APIRouter()

# ✅ 요청 스키마 정의
class TaggingRequest(BaseModel):
    image_urls: List[str]
    face_database: Dict = Field(default_factory=dict)  # 기존 얼굴 데이터베이스 포함

# ✅ 태깅 모델 인스턴스 생성
place_tagger = PlaceTagger()
location_tagger = LocationTagger()
companion_tagger = CompanionTagger()

@router.post("/generate-tags")
async def generate_tags(request: TaggingRequest):
    """
    🔹 AI 태깅 엔드포인트
    - 장소 태깅 (CLIP)
    - 지역 태깅 (GPS → 주소 변환)
    - 인물 태깅 (DeepFace + DB 비교)
    """
    try:
        results = []
        updated_face_database = request.face_database.copy()

        # ✅ 장소 태깅
        try:
            place_tags = place_tagger.predict_places(request.image_urls)
        except Exception as e:
            print(f"⚠️ 장소 태깅 실패: {e}")
            place_tags = {url: {"error": "장소 태그 생성 실패"} for url in request.image_urls}

        # ✅ 지역 태깅 (GPS 정보 기반)
        try:
            location_tags = location_tagger.predict_locations(request.image_urls)
        except Exception as e:
            print(f"⚠️ 지역 태깅 실패: {e}")
            location_tags = {url: {"error": "지역 태그 생성 실패"} for url in request.image_urls}

        # ✅ 인물 태깅 수행 (배치 내 클러스터링 + 기존 DB 비교)
        try:
            companion_tags, updated_face_database = companion_tagger.process_faces(
                request.image_urls, request.face_database  # ✅ 오류 해결
            )

        except Exception as e:
            print(f"⚠️ 인물 태깅 실패: {e}")
            companion_tags = {url: {"error": "인물 태그 생성 실패"} for url in request.image_urls}

        # ✅ 이미지별 태그 응답 구조화
        for url in request.image_urls:
            results.append({
                "image_url": url,
                "place_tag": place_tags.get(url, {"error": "장소 태그 없음"}),
                "location_tag": location_tags.get(url, {"error": "지역 태그 없음"}),
                "companion_tag": companion_tags.get(url, {"error": "인물 태그 없음"})
            })

        return {
            "results": results,
            "updated_face_database": updated_face_database  # 업데이트된 얼굴 DB 반환
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"🚨 서버 오류 발생: {str(e)}")
