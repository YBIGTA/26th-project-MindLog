from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Dict
from collections import Counter
from app.database import get_db
from app.models.diary_model import Diary
from app.routers.auth import get_current_user
import urllib.parse

router = APIRouter(tags=["Feeling"])

# ✅ 감정 기본 리스트 (모든 감정을 포함)
ALL_EMOTIONS = ["기쁨", "신뢰", "긴장", "놀람", "슬픔", "혐오", "격노", "열망"]


# 🟢 1. 1년 동안 가장 많이 나온 감정 조회
@router.get("/archive/feeling")
def get_most_common_feeling(year: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    """특정 연도에서 가장 많이 등장한 감정 반환 (현재 사용자 기준)"""

    feelings = db.query(Diary.emotions).filter(
        Diary.user_id == user.id,  # ✅ 현재 사용자만 필터링
        Diary.date >= f"{year}-01-01",
        Diary.date <= f"{year}-12-31",
        Diary.emotions.isnot(None)
    ).all()

    # 감정을 개별 요소로 분리하여 카운트
    emotion_list = []
    for f in feelings:
        if f[0]:  # None 체크
            emotion_list.extend(f[0].split(", "))

    if not emotion_list:
        raise HTTPException(
            status_code=404, detail="No data found for the given year")

    # ✅ 가장 많이 등장한 감정 찾기
    emotion_counts = Counter(emotion_list)
    most_common_emotion = max(emotion_counts, key=emotion_counts.get)

    return {"emotion": most_common_emotion}


# 🟢 2. 1년 단위 감정 등장 횟수 조회
@router.get("/feeling", response_model=Dict[str, int])
def get_feeling_distribution(year: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    """특정 연도의 감정별 등장 횟수를 반환 (현재 사용자 기준, 누락된 감정은 0)"""

    feelings = db.query(Diary.emotions).filter(
        Diary.user_id == user.id,
        Diary.date >= f"{year}-01-01",
        Diary.date <= f"{year}-12-31",
        Diary.emotions.isnot(None)
    ).all()

    emotion_list = []
    for f in feelings:
        if f[0]:
            emotion_list.extend(f[0].split(", "))

    if not emotion_list:
        return {emotion: 0 for emotion in ALL_EMOTIONS}

    emotion_counts = Counter(emotion_list)
    result = {emotion: emotion_counts.get(
        emotion, 0) for emotion in ALL_EMOTIONS}

    return result


# 🟢 3. 특정 감정의 월별 출현 횟수 조회
@router.get("/feeling/{emotion}")
def get_monthly_feeling_count(emotion: str, year: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    """특정 감정이 등장한 월별 횟수를 조회 (현재 사용자 기준)"""

    decoded_emotion = urllib.parse.unquote(emotion)  # ✅ URL 인코딩된 감정명 디코딩

    feelings = db.query(Diary.date).filter(
        Diary.user_id == user.id,  # ✅ 현재 사용자 필터링
        # ✅ 감정 포함 여부 조회 (대소문자 무시)
        Diary.emotions.ilike(f"%{decoded_emotion}%"),
        Diary.date >= f"{year}-01-01",
        Diary.date <= f"{year}-12-31"
    ).all()

    month_count = {m: 0 for m in ["JAN", "FEB", "MAR", "APR",
                                  "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]}

    for (date,) in feelings:
        month_str = date.strftime("%b").upper()
        month_count[month_str] += 1

    return month_count
