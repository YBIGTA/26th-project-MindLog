import random
from typing import List, Dict, Optional

class DiaryGenerator:
    """일기 텍스트 자동 생성 모델"""
    
    def __init__(self):
        # 감정별 표현 템플릿
        self.emotion_expressions = {
            "기쁨": {
                "starters": [
                    "오늘은 정말 기분 좋은 하루였다",
                    "마음이 한껏 들뜬 하루를 보냈다", 
                    "행복한 기운이 가득한 시간이었다",
                    "웃음이 끊이지 않는 즐거운 하루였다"
                ],
                "connectors": [
                    "함께 있으니 더욱 즐거웠고",
                    "기쁨을 나누니 배가 되는 느낌이었다",
                    "소중한 순간들이 계속 이어졌고",
                    "행복한 에너지가 전해졌다"
                ],
                "endings": [
                    "이런 날들이 많았으면 좋겠다",
                    "감사한 마음으로 하루를 마무리한다",
                    "정말 특별한 하루였다",
                    "행복한 기억으로 남을 것 같다"
                ]
            },
            "슬픔": {
                "starters": [
                    "마음이 무거운 하루였다",
                    "조금은 우울한 기분으로 시간을 보냈다",
                    "어딘가 허전하고 쓸쓸한 느낌이 들었다",
                    "마음 한구석이 아린 하루였다"
                ],
                "connectors": [
                    "혼자만의 시간이 길게 느껴졌고",
                    "생각에 잠기게 되는 시간이었다",
                    "조용히 내 마음을 들여다보게 됐다",
                    "감정을 정리하는 시간이 필요했다"
                ],
                "endings": [
                    "내일은 좀 더 나아지길 바란다",
                    "이런 감정도 나의 일부라고 받아들인다",
                    "시간이 지나면 괜찮아질 거라 믿는다",
                    "때로는 이런 날도 필요한 것 같다"
                ]
            },
            "격노": {
                "starters": [
                    "오늘은 화가 치밀어 오르는 일이 있었다",
                    "억울하고 답답한 마음이 가득했다",
                    "참기 힘든 순간들이 있었던 하루였다",
                    "속이 끓어오르는 것 같은 하루였다"
                ],
                "connectors": [
                    "감정을 억누르기가 쉽지 않았고",
                    "마음을 진정시키려 노력했지만",
                    "답답한 기분을 떨쳐내기 어려웠다",
                    "분노를 다스리는 것이 힘들었다"
                ],
                "endings": [
                    "차분히 생각을 정리해봐야겠다",
                    "감정을 건강하게 표현하는 법을 배워야겠다",
                    "내일은 더 평온한 하루가 되길 바란다",
                    "이런 감정도 지나갈 것이라 믿는다"
                ]
            },
            "긴장": {
                "starters": [
                    "마음이 불안하고 초조한 하루였다",
                    "신경이 예민해지는 것 같은 하루였다",
                    "걱정이 앞서는 시간들이 많았다",
                    "마음이 차분하지 않았던 하루였다"
                ],
                "connectors": [
                    "계속 신경 쓰이는 것들이 많았고",
                    "마음을 진정시키려 애썼지만",
                    "불안한 기분을 떨치기 어려웠다",
                    "긴장을 풀기가 쉽지 않았다"
                ],
                "endings": [
                    "깊게 숨을 쉬며 마음을 가라앉혀봐야겠다",
                    "내일은 더 여유로운 마음을 가져보자",
                    "이런 감정도 자연스러운 것이라고 생각한다",
                    "차분히 하나씩 해결해나가면 될 것 같다"
                ]
            },
            "신뢰": {
                "starters": [
                    "마음이 든든하고 안정된 하루였다",
                    "믿음직한 사람들과 함께한 시간이었다",
                    "안전하고 편안한 기분으로 보낸 하루였다",
                    "따뜻한 신뢰감이 느껴지는 하루였다"
                ],
                "connectors": [
                    "함께 있으면 마음이 편해졌고",
                    "서로를 믿고 의지할 수 있어서 좋았다",
                    "든든한 지지를 받는 기분이었다",
                    "안정감 속에서 시간을 보낼 수 있었다"
                ],
                "endings": [
                    "이런 관계들이 정말 소중하다고 느꼈다",
                    "믿을 수 있는 사람들이 있어서 감사하다",
                    "서로에 대한 신뢰가 더욱 깊어진 것 같다",
                    "안정된 마음으로 하루를 마친다"
                ]
            },
            "놀람": {
                "starters": [
                    "예상하지 못한 일들이 있었던 하루였다",
                    "깜짝 놀라는 순간들이 많았다",
                    "뜻밖의 일들로 가득한 하루였다",
                    "예측할 수 없는 하루를 보냈다"
                ],
                "connectors": [
                    "순간순간이 새롭고 신선했고",
                    "미처 생각하지 못했던 일들이 벌어졌다",
                    "놀라운 경험들이 계속 이어졌다",
                    "예상을 뛰어넘는 일들이 있었다"
                ],
                "endings": [
                    "인생은 정말 예측할 수 없는 것 같다",
                    "새로운 경험들로 가득한 하루였다",
                    "이런 놀라운 순간들이 삶의 재미인 것 같다",
                    "매일이 새로운 발견의 연속이다"
                ]
            },
            "혐오": {
                "starters": [
                    "불쾌한 기분이 드는 일들이 있었다",
                    "마음에 들지 않는 상황들을 겪었다",
                    "짜증이 나고 답답한 하루였다",
                    "기분이 좋지 않은 일들이 있었던 하루였다"
                ],
                "connectors": [
                    "참고 넘어가기가 쉽지 않았고",
                    "불편한 감정을 정리하려 노력했지만",
                    "마음의 평정을 찾기가 어려웠다",
                    "부정적인 감정을 떨쳐내려 애썼다"
                ],
                "endings": [
                    "이런 감정도 받아들이며 넘어가야겠다",
                    "내일은 더 좋은 하루가 되길 바란다",
                    "불쾌한 기분도 시간이 지나면 사라질 것이다",
                    "긍정적인 마음으로 전환해보려 한다"
                ]
            },
            "열망": {
                "starters": [
                    "무언가를 간절히 바라는 마음이 컸던 하루였다",
                    "목표를 향한 열정이 가득한 시간이었다",
                    "꿈과 희망으로 충만했던 하루였다",
                    "앞으로의 일들이 기대되는 하루였다"
                ],
                "connectors": [
                    "더 나은 내일을 꿈꾸며",
                    "목표를 향해 한 걸음씩 나아가고 있다",
                    "열정적으로 시간을 보낼 수 있었고",
                    "희망찬 미래를 그려보는 시간이었다"
                ],
                "endings": [
                    "꿈을 이루기 위해 계속 노력해야겠다",
                    "이런 열정을 잃지 않고 싶다",
                    "목표를 향해 꾸준히 걸어가고 싶다",
                    "희망을 품고 내일을 맞이하고 싶다"
                ]
            }
        }
        
        # 장소별 표현
        self.place_expressions = {
            "카페": [
                "아늑한 카페에서", "향긋한 커피향이 가득한 카페에서", "조용한 카페 한구석에서",
                "따뜻한 분위기의 카페에서", "커피 한 잔과 함께", "카페의 잔잔한 음악을 들으며"
            ],
            "식당": [
                "맛있는 음식을 먹으며", "정겨운 식당에서", "분위기 좋은 레스토랑에서",
                "함께 식사를 하며", "맛집에서 시간을 보내며", "좋은 음식과 함께"
            ],
            "공원": [
                "자연 속에서", "공원을 걸으며", "푸른 잔디 위에서", "나무 그늘 아래서",
                "산책을 하며", "신선한 공기를 마시며"
            ],
            "집": [
                "편안한 집에서", "아늑한 우리 집에서", "집에서 여유롭게", "가족과 함께 집에서",
                "집에서 휴식을 취하며", "따뜻한 집에서"
            ],
            "학교": [
                "학교에서", "캠퍼스에서", "강의실에서", "도서관에서", "학교 생활을 하며"
            ],
            "직장": [
                "직장에서", "회사에서", "사무실에서", "업무를 하며", "동료들과 함께"
            ],
            "폭포": [
                "웅장한 폭포 앞에서", "물소리가 시원한 폭포에서", "폭포의 장관을 바라보며", 
                "시원한 물줄기가 떨어지는 폭포에서", "자연의 웅장함을 느끼며", "폭포 소리에 마음이 정화되며"
            ],
            "산": [
                "산 속에서", "산을 오르며", "산 정상에서", "산길을 걸으며", 
                "자연 속에서", "맑은 공기를 마시며", "산의 정취를 느끼며"
            ],
            "바다": [
                "바다를 바라보며", "파도소리를 들으며", "해변에서", "바닷가에서", 
                "시원한 바닷바람을 맞으며", "넓은 바다를 보며"
            ],
            "강": [
                "강가에서", "강을 따라 걸으며", "물소리를 들으며", "강의 흐름을 보며",
                "시원한 물가에서", "자연의 소리와 함께"
            ],
            "호수": [
                "고요한 호수에서", "호수를 바라보며", "잔잔한 물결을 보며", 
                "평화로운 호수 가에서", "호수의 아름다움을 감상하며"
            ],
            "계곡": [
                "시원한 계곡에서", "계곡의 맑은 물소리를 들으며", "계곡을 따라 걸으며",
                "자연의 시원함을 느끼며", "계곡의 청량함 속에서"
            ],
            "숲": [
                "울창한 숲에서", "숲길을 걸으며", "나무들 사이에서", "숲의 고요함 속에서",
                "자연의 향기를 맡으며", "숲속 산책을 하며"
            ]
        }
        
        # 동행인별 표현
        self.companion_expressions = {
            "친구": [
                "친구와 함께", "소중한 친구들과", "오랜 친구와", "좋은 친구들과 시간을 보내며",
                "친구와 이야기하며", "친구와 추억을 만들며"
            ],
            "가족": [
                "가족과 함께", "소중한 가족들과", "가족과 시간을 보내며", "가족과 대화하며",
                "가족의 따뜻함을 느끼며", "가족과 소중한 시간을"
            ],
            "연인": [
                "연인과 함께", "사랑하는 사람과", "연인과 달콤한 시간을", "연인과 데이트하며",
                "특별한 사람과", "연인과 행복한 시간을"
            ],
            "동료": [
                "동료와 함께", "직장 동료들과", "팀원들과", "동료와 협업하며",
                "함께 일하는 사람들과", "동료와 소통하며"
            ],
            "혼자": [
                "혼자만의 시간을 가지며", "조용히 혼자서", "나만의 시간 속에서", "혼자서 생각에 잠기며",
                "개인적인 시간을 보내며", "혼자만의 공간에서"
            ]
        }

    def generate_diary_text(self, 
                          emotions: List[str],
                          tags: List[Dict],
                          user_text: Optional[str] = None) -> str:
        """
        감정과 태그 정보를 바탕으로 일기 텍스트를 생성합니다.
        
        Args:
            emotions: 선택된 감정 리스트
            tags: 이미지에서 추출된 태그 정보 [{"type": "장소", "tag_name": "카페"}, ...]
            user_text: 사용자가 작성한 텍스트 (선택사항)
            
        Returns:
            생성된 일기 텍스트
        """
        
        # 기본 감정 선택 (첫 번째 감정을 메인으로)
        main_emotion = emotions[0] if emotions else "기쁨"
        
        # 태그 분류
        place_tags = [tag["tag_name"] for tag in tags if tag["type"] == "장소"]
        companion_tags = [tag["tag_name"] for tag in tags if tag["type"] == "인물"]
        location_tags = [tag["tag_name"] for tag in tags if tag["type"] == "지역"]
        
        # 텍스트 구성 요소들
        parts = []
        
        # 1. 시작 문장 (감정 기반)
        if main_emotion in self.emotion_expressions:
            starter = random.choice(self.emotion_expressions[main_emotion]["starters"])
            parts.append(starter)
        
        # 2. 장소 정보 추가
        if place_tags:
            place = place_tags[0]
            if place in self.place_expressions:
                place_expr = random.choice(self.place_expressions[place])
                parts.append(f"{place_expr}")
        
        # 3. 동행인 정보 추가
        if companion_tags:
            companion = companion_tags[0]
            if companion in self.companion_expressions:
                companion_expr = random.choice(self.companion_expressions[companion])
                if len(parts) > 1:
                    parts[-1] += f" {companion_expr}"
                else:
                    parts.append(companion_expr)
        elif not companion_tags:  # 혼자인 경우
            if place_tags and len(parts) > 1:
                parts[-1] += " 혼자만의 시간을 가지며"
        
        # 4. 사용자 텍스트 통합
        if user_text and user_text.strip():
            parts.append(f"{user_text.strip()}")
        
        # 5. 연결 문장 (감정 기반)
        if main_emotion in self.emotion_expressions and len(parts) > 1:
            connector = random.choice(self.emotion_expressions[main_emotion]["connectors"])
            parts.append(connector)
        
        # 6. 마무리 문장 (감정 기반)
        if main_emotion in self.emotion_expressions:
            ending = random.choice(self.emotion_expressions[main_emotion]["endings"])
            parts.append(ending)
        
        # 여러 감정이 있는 경우 추가 표현
        if len(emotions) > 1:
            other_emotions = emotions[1:]
            emotion_desc = self._get_multiple_emotion_description(other_emotions)
            if emotion_desc:
                parts.insert(-1, emotion_desc)
        
        # 문장 조합
        diary_text = self._combine_sentences(parts)
        
        return diary_text
    
    def _get_multiple_emotion_description(self, emotions: List[str]) -> str:
        """여러 감정을 자연스럽게 표현"""
        emotion_mappings = {
            "기쁨": "기쁘면서도",
            "슬픔": "슬프면서도", 
            "격노": "화가 나면서도",
            "긴장": "불안하면서도",
            "신뢰": "안정감을 느끼면서도",
            "놀람": "놀라면서도",
            "혐오": "불쾌하면서도",
            "열망": "열망하면서도"
        }
        
        descriptions = []
        for emotion in emotions[:2]:  # 최대 2개까지만
            if emotion in emotion_mappings:
                descriptions.append(emotion_mappings[emotion])
        
        if descriptions:
            return f"복잡한 감정이 교차했다. {' '.join(descriptions)} 여러 생각이 들었다."
        
        return ""
    
    def _combine_sentences(self, parts: List[str]) -> str:
        """문장들을 자연스럽게 조합"""
        if not parts:
            return "오늘 하루를 기록해본다."
        
        # 문장 끝 처리
        processed_parts = []
        for i, part in enumerate(parts):
            part = part.strip()
            if not part:
                continue
                
            # 마지막 문장이 아니고 마침표로 끝나지 않으면 처리
            if i < len(parts) - 1:
                if not part.endswith(('.', '다', '었다', '았다', '였다')):
                    part += "."
            else:  # 마지막 문장
                if not part.endswith('.'):
                    part += "."
            
            processed_parts.append(part)
        
        return " ".join(processed_parts)