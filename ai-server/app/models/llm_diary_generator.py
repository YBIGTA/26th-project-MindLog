import openai
from typing import List, Dict, Optional
import os
import json

class LLMDiaryGenerator:
    """LLM을 사용한 일기 텍스트 생성기"""
    
    def __init__(self):
        # Upstage Solar API 설정
        try:
            self.client = openai.OpenAI(
                api_key="up_yPuWC5yW7lgmZYNEuDuSpaJznK9bV",
                base_url="https://api.upstage.ai/v1"
            )
            self.use_llm = True
            print("✅ Upstage Solar LLM 연결 성공")
        except Exception as e:
            print(f"⚠️ Upstage Solar API 연결 실패: {str(e)}. Fallback 모드로 실행합니다.")
            self.client = None
            self.use_llm = False
        
        # 감정별 기본 컨텍스트
        self.emotion_contexts = {
            "기쁨": "즐겁고 행복한 기분",
            "슬픔": "우울하고 슬픈 기분", 
            "격노": "화가 나고 분노한 기분",
            "긴장": "불안하고 긴장된 기분",
            "신뢰": "안정되고 믿음이 가는 기분",
            "놀람": "놀랍고 신기한 기분",
            "혐오": "불쾌하고 짜증나는 기분",
            "열망": "간절하고 열정적인 기분"
        }
    
    def generate_diary_text(self, 
                          emotions: List[str],
                          tags: List[Dict],
                          user_text: Optional[str] = None) -> str:
        """
        LLM을 사용해서 감정과 태그 정보를 바탕으로 일기 텍스트를 생성
        """
        try:
            # API 키가 없으면 바로 fallback 사용
            if not self.use_llm:
                print("🔄 Fallback 모드로 일기 생성")
                return self._fallback_generation(emotions, tags, user_text)
            
            # 프롬프트 구성
            prompt = self._build_prompt(emotions, tags, user_text)
            
            print(f"📝 LLM 프롬프트: {prompt}")
            
            # Upstage Solar API 호출
            response = self.client.chat.completions.create(
                model="solar-pro2",
                messages=[
                    {
                        "role": "system", 
                        "content": "당신은 일기 작성 도우미입니다. 사용자가 작성한 내용이 있다면 그 내용을 중심으로 하여 자연스럽게 확장하거나 보완하세요. 사용자의 어조와 감정을 유지하면서 일관성 있는 일기를 작성하세요. 일기 내용만 작성하고 설명이나 추가 코멘트는 절대 포함하지 마세요."
                    },
                    {
                        "role": "user", 
                        "content": prompt
                    }
                ],
                max_tokens=200,
                temperature=0.8,  # 창의성을 위해 높게 설정
                stream=False
            )
            
            generated_text = response.choices[0].message.content.strip()
            print(f"✅ LLM 생성 결과: {generated_text}")
            
            return generated_text
            
        except Exception as e:
            print(f"❌ LLM 일기 생성 실패: {str(e)}")
            # LLM 실패시 기본 템플릿 사용
            return self._fallback_generation(emotions, tags, user_text)
    
    def _build_prompt(self, emotions: List[str], tags: List[Dict], user_text: Optional[str]) -> str:
        """LLM을 위한 프롬프트 구성"""
        
        prompt_parts = []
        
        # 사용자 텍스트 분석
        user_text_length = 0
        if user_text and user_text.strip():
            user_text_length = len(user_text.strip().split())
        
        # 사용자 텍스트를 우선적으로 배치
        if user_text and user_text.strip():
            prompt_parts.append(f"사용자가 작성한 내용: {user_text.strip()}")
        
        # 감정 정보 추가
        if emotions:
            emotion_desc = ", ".join([self.emotion_contexts.get(emotion, emotion) for emotion in emotions])
            prompt_parts.append(f"오늘의 감정: {emotion_desc}")
        
        # 장소/태그 정보 추가
        if tags:
            places = [tag["tag_name"] for tag in tags if tag["type"] == "장소"]
            people = [tag["tag_name"] for tag in tags if tag["type"] == "인물"]
            locations = [tag["tag_name"] for tag in tags if tag["type"] == "지역"]
            
            if places:
                prompt_parts.append(f"장소: {', '.join(places)}")
            if people:
                prompt_parts.append(f"함께한 사람: {', '.join(people)}")
            if locations:
                prompt_parts.append(f"지역: {', '.join(locations)}")
        
        # 최종 프롬프트 - 사용자 텍스트 길이에 따른 적응적 지시
        context = "\n".join(prompt_parts)
        
        if user_text_length == 0:
            # 사용자 텍스트가 없는 경우
            instruction = """위 정보를 바탕으로 자연스럽고 일상적인 일기를 2-3문장으로 작성해주세요.
- 일상 대화처럼 자연스럽게 표현하세요
- 간단하고 솔직한 느낌으로 작성하세요
- "~했다", "~였다" 등의 과거형으로 담담하게 서술하세요"""
        elif user_text_length <= 5:
            # 사용자 텍스트가 짧은 경우 (1-5단어)
            instruction = """사용자가 작성한 내용을 중심으로 하여 자연스럽게 확장한 일기를 2-3문장으로 작성해주세요.
- 사용자의 원본 내용을 존중하면서 보완해주세요
- 사용자의 어조와 감정을 유지해주세요
- 장소나 감정 정보를 자연스럽게 포함시켜주세요
- 과도한 수식어는 피하고 일상적으로 작성해주세요"""
        else:
            # 사용자 텍스트가 충분한 경우 (6단어 이상)
            instruction = """사용자가 작성한 내용을 바탕으로 하여 보완하고 정리한 일기를 작성해주세요.
- 사용자의 원본 내용과 어조를 최대한 유지해주세요
- 중복되는 내용은 피하면서 자연스럽게 연결해주세요
- 장소나 감정 정보가 있다면 자연스럽게 통합해주세요
- 전체적으로 2-3문장으로 정리해주세요"""
        
        final_prompt = f"""{context}

{instruction}"""
        
        return final_prompt
    
    def _fallback_generation(self, emotions: List[str], tags: List[Dict], user_text: Optional[str]) -> str:
        """LLM 실패시 사용할 향상된 생성기"""
        
        import random
        
        main_emotion = emotions[0] if emotions else "기쁨"
        place_tags = [tag["tag_name"] for tag in tags if tag["type"] == "장소"]
        people_tags = [tag["tag_name"] for tag in tags if tag["type"] == "인물"]
        
        # 감정별 자연스러운 시작 문장
        emotion_starters = {
            "기쁨": [
                "기분이 좋았다.",
                "즐거운 시간을 보냈다.",
                "웃을 일이 많았던 하루였다.",
                "마음이 가벼웠다."
            ],
            "슬픔": [
                "조용한 하루를 보냈다.",
                "생각이 많았다.",
                "마음이 무거웠다.",
                "혼자만의 시간이 필요했다."
            ],
            "격노": [
                "화가 났다.",
                "짜증이 났다.",
                "감정 조절이 어려웠다.",
                "마음이 복잡했다."
            ],
            "긴장": [
                "불안했다.",
                "긴장된 하루였다.",
                "마음이 편하지 않았다.",
                "걱정이 많았다."
            ],
            "신뢰": [
                "안정된 기분이었다.",
                "마음이 편했다.",
                "든든한 느낌이었다.",
                "믿을 수 있는 하루였다."
            ],
            "놀람": [
                "놀라운 일이 있었다.",
                "예상치 못한 일들이 있었다.",
                "신기한 경험을 했다.",
                "새로운 발견이 있었다."
            ],
            "혐오": [
                "불쾌한 일이 있었다.",
                "기분이 나빴다.",
                "짜증스러운 일들이 있었다.",
                "마음이 상했다."
            ],
            "열망": [
                "뭔가 간절했다.",
                "목표가 생겼다.",
                "열정이 생겼다.",
                "도전하고 싶었다."
            ]
        }
        
        # 장소별 간단한 표현
        place_descriptions = {
            "폭포": [
                "폭포 소리가 시원했다.",
                "물줄기가 장관이었다.",
                "폭포를 보니 기분이 상쾌했다."
            ],
            "산": [
                "산 공기가 맑았다.",
                "산을 걸으니 좋았다.",
                "풍경이 예뻤다.",
                "등산로가 힘들었지만 보람있었다."
            ],
            "바다": [
                "바다가 넓고 시원했다.",
                "파도 소리가 좋았다.",
                "바다를 보니 마음이 편해졌다.",
                "바닷바람이 시원했다."
            ],
            "카페": [
                "커피가 맛있었다.",
                "카페 분위기가 좋았다.",
                "조용해서 좋았다.",
                "여유있는 시간을 보냈다."
            ],
            "공원": [
                "산책하니 좋았다.",
                "공원이 한적했다.",
                "나무와 꽃들이 예뻤다.",
                "걷기 좋은 날씨였다."
            ],
            "집": [
                "집에서 쉬었다.",
                "집이 편했다.",
                "혼자만의 시간을 보냈다.",
                "푹 쉬었다."
            ]
        }
        
        # 사용자 텍스트 길이 분석
        user_text_length = 0
        if user_text and user_text.strip():
            user_text_length = len(user_text.strip().split())
        
        # 문장 구성 - 사용자 텍스트를 우선 고려
        parts = []
        
        if user_text and user_text.strip():
            # 사용자 텍스트가 있는 경우, 이를 중심으로 확장
            user_content = user_text.strip()
            
            if user_text_length <= 3:
                # 짧은 사용자 텍스트는 시작 문장으로 사용
                parts.append(user_content)
                
                # 감정과 장소 정보를 자연스럽게 추가
                if place_tags:
                    place = place_tags[0]
                    place_options = place_descriptions.get(place, [f"{place}에서의 시간이었다."])
                    parts.append(random.choice(place_options))
                
                # 감정 기반 마무리
                if main_emotion in emotion_starters:
                    feeling_endings = {
                        "기쁨": ["기분이 좋았다.", "즐거웠다."],
                        "슬픔": ["마음이 무거웠다.", "조용한 시간이었다."],
                        "격노": ["화가 났다.", "마음이 복잡했다."],
                        "긴장": ["불안했다.", "긴장됐다."],
                        "신뢰": ["마음이 편했다.", "든든했다."],
                        "놀람": ["놀라웠다.", "신기했다."],
                        "혐오": ["불쾌했다.", "기분이 나빴다."],
                        "열망": ["간절했다.", "열정적이었다."]
                    }
                    if main_emotion in feeling_endings:
                        parts.append(random.choice(feeling_endings[main_emotion]))
            else:
                # 긴 사용자 텍스트는 그대로 사용하고 보완만
                parts.append(user_content)
                
                # 추가 정보가 있으면 간단히 보완
                if place_tags and place_tags[0].lower() not in user_content.lower():
                    place = place_tags[0]
                    parts.append(f"{place}에서였다.")
                
                # 감정이 명시적으로 드러나지 않았다면 추가
                emotion_words = ["기쁘", "슬프", "화", "불안", "편", "놀라", "싫", "간절"]
                if not any(word in user_content for word in emotion_words):
                    if main_emotion in ["기쁨"]:
                        parts.append("좋았다.")
                    elif main_emotion in ["슬픔"]:
                        parts.append("조금 우울했다.")
        else:
            # 사용자 텍스트가 없는 경우 기존 로직 사용
            # 1. 감정 기반 시작 문장
            starter_options = emotion_starters.get(main_emotion, ["오늘 하루를 기록해본다."])
            parts.append(random.choice(starter_options))
            
            # 2. 장소 설명
            if place_tags:
                place = place_tags[0]
                place_options = place_descriptions.get(place, [f"{place}에서 특별한 시간을 보냈다."])
                parts.append(random.choice(place_options))
            
            # 3. 동행인 정보
            if people_tags:
                if len(people_tags) == 1:
                    parts.append(f"{people_tags[0]}와 함께 있어서 더욱 의미 있는 시간이었다.")
                else:
                    parts.append(f"소중한 사람들과 함께 보낸 따뜻한 시간이었다.")
            
            # 4. 간단한 마무리 (선택적으로만 추가)
            if random.choice([True, False]):  # 50% 확률로 마무리 문장 추가
                simple_endings = [
                    "나름 괜찮은 하루였다.",
                    "좋은 시간이었다.",
                    "오늘도 지나갔다.",
                    "",  # 빈 문자열로 마무리 없음
                    ""
                ]
                ending = random.choice(simple_endings)
                if ending:  # 빈 문자열이 아닌 경우만 추가
                    parts.append(ending)
        
        # 최종 조합
        return " ".join(parts)