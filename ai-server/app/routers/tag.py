from fastapi import APIRouter, HTTPException
from app.models.place_tag import PlaceTagger
from app.models.location_tag import LocationTagger
from app.models.companion_tag import CompanionTagger
from typing import List, Dict
from pydantic import BaseModel
import re
import requests
from io import BytesIO
from PIL import Image

router = APIRouter()

def convert_image_url(url: str) -> str:
    """Google Drive URL 변환"""
    match = re.search(r"file/d/([^/]+)/view", url)
    if match:
        image_id = match.group(1)
        return f"https://drive.google.com/uc?id={image_id}"
    
    return url  # ✅ 기타 URL은 그대로 반환

def download_image(image_url: str):
    """🔹 이미지 다운로드 후 PIL 객체로 변환"""
    try:
        response = requests.get(image_url, timeout=5)
        response.raise_for_status()
        image = Image.open(BytesIO(response.content))

        # ✅ CMYK → RGB 변환 (색상 문제 방지)
        if image.mode != "RGB":
            image = image.convert("RGB")
        
        return image

    except Exception as e:
        print(f"⚠️ 이미지 다운로드 실패: {image_url}, 오류: {e}")
        return None

def resize_image(image: Image.Image, max_width: int, max_height: int):
    """🔹 이미지 크기를 조정하여 메모리 최적화"""
    width, height = image.size
    if width > max_width or height > max_height:
        scale = min(max_width / width, max_height / height)
        new_size = (int(width * scale), int(height * scale))
        image = image.resize(new_size, Image.LANCZOS)
    
    return image

# ✅ 요청 스키마 정의
class TaggingRequest(BaseModel):
    image_urls: List[str]

# ✅ 태깅 모델 인스턴스 생성
place_tagger = PlaceTagger()
location_tagger = LocationTagger()
companion_tagger = CompanionTagger()

@router.post("/generate-tags")
async def generate_tags(request: TaggingRequest):
    try:
        results = []

        # ✅ 이미지 URL 변환 (Google Drive → 변환, 기타 URL은 그대로 사용)
        image_urls = [convert_image_url(url) for url in request.image_urls]

        # ✅ 한 번만 이미지를 다운로드하여 장소 태깅 및 얼굴 태깅 모델에 전달
        image_data_dict = {}
        for url in image_urls:
            image = download_image(url)
            if image:
                image_data_dict[url] = {
                    "place": resize_image(image.copy(), 512, 512),  # ✅ 장소 태깅용 (작게)
                    "face": resize_image(image.copy(), 1024, 1024)  # ✅ 얼굴 태깅용 (크게)
                }
            else:
                image_data_dict[url] = None

        # ✅ 태깅 수행 (변환된 URL & 다운로드된 이미지 사용!)
        place_tags = place_tagger.predict_places({url: img["place"] for url, img in image_data_dict.items() if img})
        location_tags = location_tagger.predict_locations(image_urls)  # ✅ 지역 태깅에 이미지 전달하지 않고 URL만 전달
        companion_tags = companion_tagger.process_faces({url: img["face"] for url, img in image_data_dict.items() if img})

        # ✅ 이미지별 응답 구조화
        for original_url, converted_url in zip(request.image_urls, image_urls):
            tags = []

            if converted_url in place_tags and "error" not in place_tags[converted_url]:
                tags.append({"type": "장소", "tag_name": place_tags[converted_url]["place"]})

            if converted_url in location_tags and "error" not in location_tags[converted_url]:
                tags.append({"type": "지역", "tag_name": location_tags[converted_url]["region"]})

            if converted_url in companion_tags and "error" not in companion_tags[converted_url]:
                for person in companion_tags[converted_url]:  # ✅ 여러 인물 태깅
                    tags.append({"type": "인물", "tag_name": person})

            results.append({"image_url": original_url, "tags": tags})  # ✅ 원래 URL 유지

        return {"results": results}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"🚨 서버 오류 발생: {str(e)}")