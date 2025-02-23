from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Dict
from collections import Counter
from app.database import get_db
from app.models.diary_model import Diary

router = APIRouter(
    tags=["Feeling"]
)

# 🟢 1. 1년 동안 가장 많이 나온 감정 조회


@router.get("/archive/feeling")
def get_most_common_feeling(year: int, db: Session = Depends(get_db)):
    feelings = db.query(Diary.emotions).filter(
        Diary.date >= f"{year}-01-01",
        Diary.date <= f"{year}-12-31",
        Diary.emotions.isnot(None)
    ).all()

    emotions = [f[0] for f in feelings if f[0]]
    if not emotions:
        raise HTTPException(
            status_code=404, detail="No data found for the given year")

    most_common = Counter(emotions).most_common(1)
    return {"emotion": most_common[0][0]}

# 🟢 2. 1년 단위 8개 감정 비율 조회


# ✅ 감정 기본 리스트 (모든 감정을 포함)
ALL_EMOTIONS = ["기쁨", "신뢰", "긴장", "놀람", "슬픔", "혐오", "격노", "열망"]


@router.get("/feeling", response_model=Dict[str, int])
def get_feeling_distribution(year: int, db: Session = Depends(get_db)):
    """ 특정 연도의 감정별 등장 횟수를 반환 (누락된 감정은 0으로 설정) """

    # 해당 연도의 다이어리에서 감정 데이터 가져오기
    feelings = db.query(Diary.emotions).filter(
        Diary.date >= f"{year}-01-01",
        Diary.date <= f"{year}-12-31",
        Diary.emotions.isnot(None)
    ).all()

    # 감정을 개별 요소로 분리하여 카운트
    emotion_list = []
    for f in feelings:
        if f[0]:  # None 체크
            emotion_list.extend(f[0].split(", "))  # ✅ 감정 리스트 분리

    # 감정이 하나도 없으면 예외 처리
    if not emotion_list:
        return {emotion: 0 for emotion in ALL_EMOTIONS}  # ✅ 모든 감정을 0으로 설정하여 반환

    # 감정별 개수 카운트
    emotion_counts = Counter(emotion_list)

    # ✅ 모든 감정을 포함하는 결과 반환 (없으면 기본값 0)
    result = {emotion: emotion_counts.get(
        emotion, 0) for emotion in ALL_EMOTIONS}

    return result

# 🟢 3. 특정 감정의 월별 출현 횟수 조회


@router.get("/{emotion}")
def get_monthly_feeling_count(emotion: str, year: int, db: Session = Depends(get_db)):
    feelings = db.query(Diary.date).filter(
        Diary.emotions == emotion,
        Diary.date >= f"{year}-01-01",
        Diary.date <= f"{year}-12-31"
    ).all()

    if not feelings:
        raise HTTPException(
            status_code=404, detail="No data found for the given emotion and year")

    month_count = {m: 0 for m in ["JAN", "FEB", "MAR", "APR",
                                  "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]}

    for (date,) in feelings:
        month_str = date.strftime("%b").upper()
        month_count[month_str] += 1

    return month_count
