from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.diary_model import Diary, Image, Tag, ImageTag
from app.schemas.diary_schema import DiaryCreate, DiaryResponse
from app.routers.auth import get_current_user
import uuid
from typing import List

router = APIRouter(prefix="/diary", tags=["Diary"])


@router.post("/", response_model=DiaryResponse, status_code=status.HTTP_201_CREATED)
def create_diary(
    diary_data: DiaryCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    new_diary = Diary(
        id=uuid.uuid4(),
        user_id=user.id,
        date=diary_data.date,
        emotions=", ".join(diary_data.emotions),  # ✅ 리스트 → 문자열 변환
        text=diary_data.text,
    )
    db.add(new_diary)
    db.flush()

    # ✅ 이미지 URL 저장 및 태그 하드코딩
    image_urls = []
    ai_results = {}
    if len(diary_data.image_urls) > 0:
        ai_results[diary_data.image_urls[0]] = [
            {"type": "인물", "tag_name": "친구"},
            {"type": "장소", "tag_name": "공원"}
        ]
    if len(diary_data.image_urls) > 1:
        ai_results[diary_data.image_urls[1]] = [
            {"type": "음식", "tag_name": "커피"},
            {"type": "장소", "tag_name": "카페"}
        ]

    tags = set()
    for url in diary_data.image_urls:
        new_image = Image(
            id=uuid.uuid4(), diary_id=new_diary.id, image_url=url)
        db.add(new_image)
        image_urls.append(url)

        for tag in ai_results.get(url, []):
            existing_tag = db.query(Tag).filter(
                Tag.tag_name == tag["tag_name"]).first()
            if not existing_tag:
                existing_tag = Tag(
                    id=uuid.uuid4(), type=tag["type"], tag_name=tag["tag_name"])
                db.add(existing_tag)
                db.flush()

            new_imagetag = ImageTag(
                image_id=new_image.id, tag_id=existing_tag.id)
            db.add(new_imagetag)
            tags.add(existing_tag)

    db.commit()
    db.refresh(new_diary)

    return DiaryResponse(
        id=new_diary.id,
        date=new_diary.date,
        image_urls=image_urls,
        emotions=diary_data.emotions,
        text=new_diary.text,
        tags=[{"id": tag.id, "type": tag.type, "tag_name": tag.tag_name}
              for tag in tags],
        created_at=new_diary.created_at
    )


@router.get("/{diary_id}", response_model=DiaryResponse)
def get_diary(diary_id: uuid.UUID, db: Session = Depends(get_db), user=Depends(get_current_user)):
    diary = db.query(Diary).filter(Diary.id == diary_id,
                                   Diary.user_id == user.id).first()
    if not diary:
        raise HTTPException(status_code=404, detail="다이어리를 찾을 수 없습니다.")

    image_urls = [image.image_url for image in diary.images]
    tags = []
    for image in diary.images:
        for image_tag in db.query(ImageTag).filter(ImageTag.image_id == image.id).all():
            tag = db.query(Tag).filter(Tag.id == image_tag.tag_id).first()
            if tag:
                tags.append({"id": tag.id, "type": tag.type,
                            "tag_name": tag.tag_name})

    return DiaryResponse(
        id=diary.id,
        date=diary.date,
        image_urls=image_urls,
        emotions=diary.emotions.split(", ") if diary.emotions else [],
        text=diary.text,
        tags=tags,
        created_at=diary.created_at
    )


@router.get("/", response_model=List[DiaryResponse])
def get_diary_list(db: Session = Depends(get_db), user=Depends(get_current_user)):
    diaries = db.query(Diary).filter(
        Diary.user_id == user.id).order_by(Diary.date.desc()).all()
    response = []
    for diary in diaries:
        image_urls = [image.image_url for image in diary.images]
        tags = []
        for image in diary.images:
            for image_tag in db.query(ImageTag).filter(ImageTag.image_id == image.id).all():
                tag = db.query(Tag).filter(Tag.id == image_tag.tag_id).first()
                if tag:
                    tags.append({"id": tag.id, "type": tag.type,
                                "tag_name": tag.tag_name})
        response.append(DiaryResponse(
            id=diary.id,
            date=diary.date,
            image_urls=image_urls,
            emotions=diary.emotions.split(", ") if diary.emotions else [],
            text=diary.text,
            tags=tags,
            created_at=diary.created_at
        ))
    return response
