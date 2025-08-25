import random
from typing import List, Dict
import os

class SimpleImageAnalyzer:
    """
    간단한 이미지 분석기 (torch 의존성 없이)
    파일명이나 간단한 규칙 기반으로 장소를 추정
    """
    
    def __init__(self):
        # 키워드 기반 장소 매핑
        self.keyword_mapping = {
            # 자연 풍경
            "폭포": ["waterfall", "fall", "cascade", "폭포", "falls"],
            "산": ["mountain", "hill", "peak", "산", "등산", "hiking", "mount", "mt", "ridge"],
            "바다": ["ocean", "sea", "beach", "wave", "바다", "해변", "파도", "seaside", "coast"],
            "강": ["river", "stream", "강", "하천", "creek", "brook"],
            "호수": ["lake", "pond", "호수", "연못", "reservoir"],
            "계곡": ["valley", "gorge", "계곡", "협곡", "ravine", "canyon"],
            "숲": ["forest", "wood", "tree", "숲", "나무", "woods", "jungle", "grove"],
            "공원": ["park", "garden", "공원", "정원", "plaza", "square"],
            "들판": ["field", "meadow", "들판", "초원", "grassland"],
            "정원": ["garden", "yard", "정원", "마당", "botanical"],
            
            # 도시/건물  
            "카페": ["cafe", "coffee", "starbucks", "카페", "커피", "caffeine", "coffeeshop"],
            "식당": ["restaurant", "food", "meal", "식당", "음식", "레스토랑", "dining", "eatery"],
            "집": ["home", "house", "room", "집", "방", "apartment", "residence"],
            "학교": ["school", "university", "college", "학교", "대학", "campus", "academy"],
            "직장": ["office", "work", "company", "직장", "회사", "사무실", "workplace", "building"],
            "상점": ["store", "shop", "market", "상점", "가게", "마트", "mall", "shopping"],
            "병원": ["hospital", "clinic", "medical", "병원", "의원", "health"],
            "도서관": ["library", "도서관", "책", "book"],
            "미술관": ["museum", "gallery", "미술관", "박물관", "전시"],
            "극장": ["theater", "cinema", "movie", "극장", "영화관", "theatre"],
            "체육관": ["gym", "fitness", "체육관", "헬스장", "sports"],
            "시장": ["market", "bazaar", "시장", "전통시장", "marketplace"]
        }
        
        # 자연 풍경 키워드들 (더 넓은 범위)
        self.nature_keywords = [
            "nature", "natural", "outdoor", "landscape", "scenic", "wild",
            "자연", "풍경", "경치", "야외", "관광", "여행", "travel", "tour",
            "national", "park", "trail", "hiking", "trekking"
        ]
        
        # 일반적인 자연 장소들 (키워드가 감지되지 않을 때 랜덤 선택용)
        self.default_nature_places = ["공원", "산", "숲", "강", "해변", "계곡", "호수"]
        self.default_urban_places = ["집", "식당", "거리", "상점", "건물", "광장"]
    
    def analyze_image_simple(self, image_url: str, user_text: str = "") -> List[Dict[str, str]]:
        """
        이미지 URL과 사용자 텍스트를 분석해서 태그 생성
        """
        tags = []
        
        # 1. 파일명에서 키워드 찾기
        filename = os.path.basename(image_url).lower() if image_url else ""
        detected_place = self._detect_place_from_text(filename)
        
        # 2. 사용자 텍스트에서 키워드 찾기
        if user_text:
            text_place = self._detect_place_from_text(user_text.lower())
            if text_place and not detected_place:
                detected_place = text_place
        
        # 3. 장소 태그 추가
        if detected_place:
            tags.append({
                "type": "장소",
                "tag_name": detected_place
            })
            print(f"🎯 키워드 기반 장소 감지: {detected_place}")
        else:
            # 자연 키워드가 있으면 자연 장소, 없으면 도시 장소 중 선택
            combined_text = (filename + " " + user_text).lower()
            if any(keyword in combined_text for keyword in self.nature_keywords):
                place = random.choice(self.default_nature_places)
                print(f"🌿 자연 키워드 감지 → 기본 자연 장소: {place}")
            else:
                place = random.choice(self.default_urban_places)
                print(f"🏙️ 도시 키워드 → 기본 도시 장소: {place}")
            
            tags.append({
                "type": "장소",
                "tag_name": place
            })
        
        return tags
    
    def _detect_place_from_text(self, text: str) -> str:
        """텍스트에서 장소 키워드를 찾아서 장소명 반환"""
        text = text.lower()
        
        # 우선순위: 정확한 매칭부터 확인
        for place, keywords in self.keyword_mapping.items():
            for keyword in keywords:
                if keyword.lower() in text:
                    print(f"🔍 키워드 '{keyword}' → 장소 '{place}' 매칭")
                    return place
        
        return ""
    
    def analyze_multiple_images(self, image_urls: List[str], user_text: str = "") -> Dict[str, List[Dict]]:
        """여러 이미지 분석"""
        results = {}
        
        for url in image_urls:
            tags = self.analyze_image_simple(url, user_text)
            results[url] = tags
            
        return results