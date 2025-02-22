import uuid
from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile, Form
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models.diary_model import Diary, Image, Tag, ImageTag
from app.schemas.diary_schema import DiaryResponse
from app.routers.auth import get_current_user
from app.core.config import s3_client, settings  # ✅ S3 클라이언트 임포트

router = APIRouter(prefix="/diary", tags=["Diary"])


@router.post("/", response_model=DiaryResponse, status_code=status.HTTP_201_CREATED)
async def create_diary(
    date: str = Form(...),  # ✅ Form 데이터로 받기
    emotions: str = Form(...),  # ✅ emotions 리스트 → JSON 문자열로 전달
    text: str = Form(...),
    images: List[UploadFile] = File(...),  # ✅ 여러 개의 이미지 파일을 받음
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    new_diary = Diary(
        id=uuid.uuid4(),
        user_id=user.id,
        date=date,
        emotions=emotions,
        text=text,
    )
    db.add(new_diary)
    db.flush()

    image_urls = []
    tags = set()

    # ✅ 1️⃣ 이미지 S3 업로드
    for image in images:
        file_extension = image.filename.split(".")[-1]
        s3_filename = f"{uuid.uuid4()}.{file_extension}"

        # S3 업로드
        s3_client.upload_fileobj(
            image.file, settings.AWS_S3_BUCKET_NAME, s3_filename)

        # ✅ 업로드된 이미지 URL 생성
        s3_url = f"https://{settings.AWS_S3_BUCKET_NAME}.s3.amazonaws.com/{s3_filename}"
        image_urls.append(s3_url)

        # ✅ 이미지 정보 저장
        new_image = Image(
            id=uuid.uuid4(), diary_id=new_diary.id, image_url=s3_url)
        db.add(new_image)
        db.flush()

        # ✅ 2️⃣ AI 서버 응답 하드코딩 (이미지별 태그 적용)
        ai_tags = [
            {"type": "장소", "tag_name": "카페"},
            {"type": "음식", "tag_name": "커피"},
        ] if len(image_urls) % 2 == 0 else [
            {"type": "인물", "tag_name": "친구"},
            {"type": "장소", "tag_name": "공원"},
        ]

        # ✅ 3️⃣ 태그 저장 및 `image_tag` 매핑
        for tag_data in ai_tags:
            tag = db.query(Tag).filter(
                Tag.tag_name == tag_data["tag_name"]).first()
            if not tag:
                tag = Tag(id=uuid.uuid4(),
                          type=tag_data["type"], tag_name=tag_data["tag_name"])
                db.add(tag)
                db.flush()

            new_image_tag = ImageTag(image_id=new_image.id, tag_id=tag.id)
            db.add(new_image_tag)
            tags.add(tag)

    db.commit()
    db.refresh(new_diary)

    return DiaryResponse(
        id=new_diary.id,
        date=new_diary.date,
        image_urls=image_urls,
        emotions=emotions.split(", "),
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
