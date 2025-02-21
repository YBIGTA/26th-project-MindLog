from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.diary_model import Diary, Image, Tag, ImageTag
from app.schemas.diary_schema import DiaryCreate, DiaryResponse
from app.routers.auth import get_current_user
import uuid
from typing import List

router = APIRouter(prefix="/diary")


@router.post("/", response_model=DiaryResponse, status_code=status.HTTP_201_CREATED)
def create_diary(
    diary_data: DiaryCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    # 1️⃣ AI 서버에 이미지 URL을 보내 태그 요청 (현재 주석 처리)
    """
    ai_response = requests.post("http://ai-server:8001/ai/generate-tags", json={"image_urls": diary_data.image_urls})
    # 이미지별 태그가 반환될 것으로 예상 (ex. { "image_url": "...", "tags": [...] })
    ai_results = ai_response.json().get("results", [])
    """

    # 2️⃣ 임시 AI 태그 하드코딩 (예시: 모든 이미지에 동일한 태그 적용)
    tags_data = [
        {"type": "인물", "tag_name": "친구"},
        {"type": "장소", "tag_name": "카페"},
        {"type": "지역", "tag_name": "서울"}
    ]

    # 3️⃣ 다이어리 생성 (emotions 컬럼 추가, image_urls는 별도 저장)
    new_diary = Diary(
        id=uuid.uuid4(),
        user_id=user.id,
        date=diary_data.date,
        emotions=diary_data.emotions,
        text=diary_data.text,
    )
    db.add(new_diary)
    db.flush()  # new_diary.id 사용을 위해 flush

    # 4️⃣ 이미지 및 태그 처리
    for url in diary_data.image_urls:
        # 이미지 생성
        new_image = Image(
            id=uuid.uuid4(),
            diary_id=new_diary.id,
            image_url=url
        )
        db.add(new_image)
        db.flush()  # new_image.id 사용을 위해 flush

        # 해당 이미지에 AI가 반환한 태그 적용
        for tag in tags_data:
            # 기존 태그 검색 (태그명 기준)
            existing_tag = db.query(Tag).filter(
                Tag.tag_name == tag["tag_name"]).first()
            if not existing_tag:
                existing_tag = Tag(
                    id=uuid.uuid4(),
                    type=tag["type"],
                    tag_name=tag["tag_name"]
                )
                db.add(existing_tag)
                db.flush()
            # 이미지와 태그 매핑 생성 (중복 매핑은 ImageTag의 PK로 방지됨)
            new_imagetag = ImageTag(
                image_id=new_image.id,
                tag_id=existing_tag.id
            )
            db.add(new_imagetag)

    # 5️⃣ DB 커밋 및 다이어리 리프레시 (이미지, 태그 관계도 함께 조회됨)
    db.commit()
    db.refresh(new_diary)

    return new_diary


@router.get("/{diary_id}", response_model=DiaryResponse)
def get_diary(diary_id: uuid.UUID, db: Session = Depends(get_db), user=Depends(get_current_user)):
    diary = db.query(Diary).filter(Diary.id == diary_id,
                                   Diary.user_id == user.id).first()
    if not diary:
        raise HTTPException(status_code=404, detail="다이어리를 찾을 수 없습니다.")
    return diary


@router.get("/", response_model=List[DiaryResponse])
def get_diary_list(db: Session = Depends(get_db), user=Depends(get_current_user)):
    diaries = db.query(Diary).filter(
        Diary.user_id == user.id).order_by(Diary.date.desc()).all()
    return diaries
