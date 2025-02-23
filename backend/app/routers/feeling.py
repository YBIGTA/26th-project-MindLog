from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
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


@router.get("/feeling")
def get_feeling_distribution(year: int, db: Session = Depends(get_db)):
    feelings = db.query(Diary.emotions).filter(
        Diary.date >= f"{year}-01-01",
        Diary.date <= f"{year}-12-31",
        Diary.emotions.isnot(None)
    ).all()

    emotions = [f[0] for f in feelings if f[0]]
    if not emotions:
        raise HTTPException(
            status_code=404, detail="No data found for the given year")

    total = len(emotions)
    emotion_counts = Counter(emotions)

    # 8개 감정 비율 계산 (퍼센트)
    emotions_list = ["기쁨", "신뢰", "긴장", "놀람",
                     "슬픔", "혐오", "격노", "열망"]
    emotion_percentages = {
        e: round((emotion_counts.get(e, 0) / total) * 100, 2) for e in emotions_list}

    return emotion_percentages

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
