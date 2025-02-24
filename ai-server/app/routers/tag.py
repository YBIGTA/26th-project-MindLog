from fastapi import APIRouter, HTTPException
from app.models.place_tag import PlaceTagger
from app.models.location_tag import LocationTagger
from app.models.companion_tag import CompanionTagger
from typing import List, Dict
from pydantic import BaseModel
import re
import requests
from io import BytesIO
from PIL import Image, ExifTags
import piexif
import aiohttp
import io

router = APIRouter()

def convert_image_url(url: str) -> str:
    """Google Drive URL 변환"""
    match = re.search(r"file/d/([^/]+)/view", url)
    if match:
        image_id = match.group(1)
        return f"https://drive.google.com/uc?id={image_id}"
    
    return url  # ✅ 기타 URL은 그대로 반환

def download_image(image_url: str):
    """🔹 이미지 다운로드 후 PIL 객체로 변환 (EXIF 데이터 유지)"""
    try:
        response = requests.get(image_url, timeout=5)
        response.raise_for_status()
        
        # 이미지 데이터를 BytesIO에 저장
        image_data = BytesIO(response.content)
        
        # PIL Image로 열기
        image = Image.open(image_data)
        
        # EXIF 데이터 디버깅
        print(f"📸 이미지 정보: {image_url}")
        print(f"- 이미지 모드: {image.mode}")
        print(f"- 이미지 포맷: {image.format}")
        print(f"- info 키: {list(image.info.keys())}")
        
        # EXIF 데이터 보존을 위한 처리
        if "exif" in image.info:
            exif_dict = piexif.load(image.info["exif"])
            print(f"- EXIF 데이터: {list(exif_dict.keys())}")
            
            # GPS 데이터 상세 확인
            if "GPS" in exif_dict:
                print(f"- GPS 데이터: {exif_dict['GPS']}")
            
            # RGB로 변환이 필요한 경우
            if image.mode != "RGB":
                original_exif = image.info.get("exif")
                image = image.convert("RGB")
                image.info["exif"] = original_exif
        else:
            print("- EXIF 데이터 없음")
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
        image_urls = []
        converted_urls = []  # 변환된 URL 저장
        image_data_dict = {}

        # 이미지 URL 처리
        for url in request.image_urls:
            try:
                # Google Drive URL 변환
                converted_url = convert_image_url(url)
                
                # 이미지 다운로드 및 변환
                async with aiohttp.ClientSession() as session:
                    async with session.get(converted_url) as response:
                        if response.status == 200:
                            image_data = await response.read()
                            image = Image.open(io.BytesIO(image_data))
                            
                            # 이미지를 RGB로 변환
                            if image.mode != 'RGB':
                                image = image.convert('RGB')
                            
                            # 각 태거에 맞는 이미지 크기로 복사
                            image_data_dict[url] = {
                                "place": image.copy().resize((512, 512)),
                                "face": image.copy().resize((1024, 1024))
                            }
                            image_urls.append(url)
                            converted_urls.append(converted_url)  # 변환된 URL 저장
                        else:
                            print(f"⚠️ 이미지 다운로드 실패: {url}")
                            results.append({"image_url": url, "tags": []})
                            continue

            except Exception as e:
                print(f"⚠️ 이미지 처리 실패: {url}, 오류: {str(e)}")
                results.append({"image_url": url, "tags": []})
                continue

        # 이미지가 하나도 처리되지 않은 경우
        if not image_data_dict:
            return {"results": results}

        # 태깅 수행
        place_tags = place_tagger.predict_places({url: data["place"] for url, data in image_data_dict.items()})
        location_tags = location_tagger.predict_locations(converted_urls)  # 변환된 URL 사용

        # 인물 태그 생성
        companion_tags = {}
        try:
            companion_tags = companion_tagger.process_faces({url: data["face"] for url, data in image_data_dict.items()})
            if companion_tags is None:
                companion_tags = {url: [] for url in image_urls}
        except Exception as e:
            print(f"⚠️ 인물 태깅 실패: {str(e)}")
            companion_tags = {url: [] for url in image_urls}

        # 이미지별 응답 구조화
        for url, converted_url in zip(image_urls, converted_urls):
            tags = []
            
            # 장소 태그 추가
            if url in place_tags and "error" not in place_tags[url]:
                tags.append({"type": "장소", "tag_name": place_tags[url]["place"]})
            
            # 지역 태그 추가 (변환된 URL 사용)
            if converted_url in location_tags and "error" not in location_tags[converted_url]:
                tags.append({"type": "지역", "tag_name": location_tags[converted_url]["region"]})
            
            # 인물 태그 추가
            if companion_tags and url in companion_tags:
                person_tags = companion_tags[url]
                if isinstance(person_tags, list):
                    for person_tag in person_tags:
                        tags.append({"type": "인물", "tag_name": person_tag})
            
            results.append({"image_url": url, "tags": tags})

        return {"results": results}
        
    except Exception as e:
        print(f"🚨 전역 에러 발생: {str(e)}")
        results = [{"image_url": url, "tags": []} for url in request.image_urls]
        return {"results": results}