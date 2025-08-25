from fastapi import APIRouter, HTTPException
from app.models.diary_generator import DiaryGenerator
from app.models.llm_diary_generator import LLMDiaryGenerator
from app.models.simple_image_analyzer import SimpleImageAnalyzer
from app.models.place_tag import PlaceTagger
# from app.models.location_tag import LocationTagger
# from app.models.companion_tag import CompanionTagger
from typing import List, Dict, Optional
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

# ✅ 모델 인스턴스 생성
diary_generator = DiaryGenerator()
llm_diary_generator = LLMDiaryGenerator()
image_analyzer = SimpleImageAnalyzer()
try:
    place_tagger = PlaceTagger()
    print("✅ PlaceTagger 초기화 성공")
except Exception as e:
    print(f"⚠️ PlaceTagger 초기화 실패, 단순 분석기 사용: {str(e)}")
    place_tagger = None
# location_tagger = LocationTagger()
# companion_tagger = CompanionTagger()

@router.post("/generate-tags")
async def generate_tags(request: TaggingRequest):
    """
    이미지 태깅 기능 (CLIP 기반 또는 키워드 기반 분석)
    """
    try:
        print(f"📸 이미지 태깅 요청: {len(request.image_urls)}개 이미지")
        results = []
        
        # CLIP 기반 place tagger 사용 시도
        if place_tagger is not None:
            print("🔬 CLIP 기반 장소 분석 사용")
            try:
                # 이미지 다운로드
                image_data_dict = {}
                for url in request.image_urls:
                    converted_url = convert_image_url(url)
                    image = download_image(converted_url)
                    if image:
                        image_data_dict[url] = image
                
                if image_data_dict:
                    # CLIP 기반 장소 예측
                    place_results = place_tagger.predict_places(image_data_dict, top_k=1)
                    
                    for url in request.image_urls:
                        tags = []
                        if url in place_results and "place" in place_results[url]:
                            place_name = place_results[url]["place"]
                            confidence = place_results[url].get("confidence", 0)
                            tags.append({
                                "type": "장소",
                                "tag_name": place_name,
                                "confidence": confidence
                            })
                            print(f"✅ CLIP 장소 분석: {place_name} (신뢰도: {confidence:.3f})")
                        
                        # 추가로 간단한 키워드 분석도 수행
                        keyword_tags = image_analyzer.analyze_image_simple(url)
                        for tag in keyword_tags:
                            if not any(t["tag_name"] == tag["tag_name"] for t in tags):
                                tags.append(tag)
                        
                        results.append({"image_url": url, "tags": tags})
                
            except Exception as e:
                print(f"⚠️ CLIP 분석 실패, 키워드 분석으로 대체: {str(e)}")
                # CLIP 실패 시 키워드 기반으로 대체
                for url in request.image_urls:
                    tags = image_analyzer.analyze_image_simple(url)
                    results.append({"image_url": url, "tags": tags})
        else:
            print("📝 키워드 기반 분석 사용")
            # 간단한 이미지 분석 (키워드 기반)
            for url in request.image_urls:
                print(f"📍 처리 중인 이미지: {url}")
                tags = image_analyzer.analyze_image_simple(url)
                print(f"✅ 생성된 태그: {tags}")
                results.append({"image_url": url, "tags": tags})
        
        return {"results": results}
        
    except Exception as e:
        print(f"🚨 태깅 에러 발생: {str(e)}")
        results = [{"image_url": url, "tags": []} for url in request.image_urls]
        return {"results": results}

# ✅ 일기 텍스트 생성 요청 스키마
class DiaryGenerationRequest(BaseModel):
    emotions: List[str]
    tags: List[Dict[str, str]]  # [{"type": "장소", "tag_name": "카페"}, ...]
    user_text: Optional[str] = None

@router.post("/generate-diary-text")
async def generate_diary_text(request: DiaryGenerationRequest):
    """
    감정과 태그 정보를 바탕으로 일기 텍스트를 자동 생성합니다.
    """
    try:
        print(f"📝 일기 텍스트 생성 요청:")
        print(f"- 감정: {request.emotions}")
        print(f"- 태그: {request.tags}")
        print(f"- 사용자 텍스트: {request.user_text}")
        
        # 사용자 텍스트에서 추가 태그 추출
        additional_tags = []
        if request.user_text:
            detected_tags = image_analyzer.analyze_image_simple("", request.user_text)
            additional_tags.extend(detected_tags)
            print(f"🔍 사용자 텍스트에서 추출한 추가 태그: {detected_tags}")
        
        # 기존 태그와 추가 태그 합치기
        all_tags = list(request.tags) + additional_tags
        
        # LLM을 사용한 일기 텍스트 생성
        generated_text = llm_diary_generator.generate_diary_text(
            emotions=request.emotions,
            tags=all_tags,
            user_text=request.user_text
        )
        
        print(f"✅ 생성된 일기 텍스트: {generated_text}")
        
        return {
            "generated_text": generated_text,
            "status": "success"
        }
        
    except Exception as e:
        print(f"🚨 일기 텍스트 생성 실패: {str(e)}")
        raise HTTPException(status_code=500, detail=f"일기 텍스트 생성 실패: {str(e)}")