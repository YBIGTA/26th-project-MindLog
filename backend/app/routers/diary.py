import uuid
import requests
import io
from PIL import Image as PILImage
from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile, Form
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.models.diary_model import Diary, Image, Tag, ImageTag
from app.schemas.diary_schema import DiaryResponse
from app.routers.auth import get_current_user
from app.core.config import s3_client, settings  # ✅ S3 클라이언트 임포트

router = APIRouter(prefix="/diary", tags=["Diary"])

AI_SERVER_URL = "http://192.168.0.16:8001/ai/generate-tags"  # ✅ AI 서버 URL


# ✅ EXIF 정보 유지하며 S3 업로드 함수
def upload_image_to_s3(image: UploadFile, s3_filename: str) -> str:
    """S3에 이미지 업로드 및 URL 반환"""
    s3_client.upload_fileobj(
        image.file,
        settings.AWS_S3_BUCKET_NAME,
        s3_filename,
        ExtraArgs={
            "ContentType": image.content_type,  # MIME 타입 유지
            "Metadata": {
                # ✅ 문자열 변환
                "original_filename": image.filename.encode('utf-8').decode('utf-8'),
            },
        },
    )

    return f"https://{settings.AWS_S3_BUCKET_NAME}.s3.amazonaws.com/{s3_filename}"


@router.post("/", response_model=DiaryResponse, status_code=status.HTTP_201_CREATED)
async def create_diary(
    date: str = Form(...),
    emotions: List[str] = Form(...),
    text: Optional[str] = Form(None),  # ✅ 선택적 필드로 변경
    images: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    new_diary = Diary(
        id=uuid.uuid4(),
        user_id=user.id,
        date=date,
        emotions=", ".join(emotions),
        text=text if text else "",  # ✅ `None`을 빈 문자열로 변환하여 Pydantic 처리 가능하게 함
    )
    db.add(new_diary)
    db.flush()

    image_urls = []
    uploaded_images = []

    # ✅ 1️⃣ 이미지 S3 업로드 (EXIF 유지)
    for image in images:
        file_extension = image.filename.split(".")[-1]
        s3_filename = f"{uuid.uuid4()}.{file_extension}"

        # ✅ 수정된 EXIF 유지 S3 업로드 함수 사용
        s3_url = upload_image_to_s3(image, s3_filename)
        image_urls.append(s3_url)

        new_image = Image(
            id=uuid.uuid4(), diary_id=new_diary.id, image_url=s3_url)
        db.add(new_image)
        uploaded_images.append(new_image)

    db.commit()
    db.refresh(new_diary)

    # ✅ 2️⃣ AI 서버에 이미지 URL 전달하여 태그 요청
    try:
        ai_response = requests.post(
            AI_SERVER_URL, json={"image_urls": image_urls})
        ai_results = ai_response.json().get("results", [])
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 서버 요청 실패: {str(e)}")

    tags = set()

    # ✅ 3️⃣ AI 서버 응답을 기반으로 태그 매핑
    for result in ai_results:
        image_url = result["image_url"]
        image = next(
            (img for img in uploaded_images if img.image_url == image_url), None)

        if not image:
            continue  # 해당 URL의 이미지가 DB에 없으면 스킵

        for tag_data in result["tags"]:
            tag = db.query(Tag).filter(
                Tag.tag_name == tag_data["tag_name"]).first()
            if not tag:
                tag = Tag(id=uuid.uuid4(),
                          type=tag_data["type"], tag_name=tag_data["tag_name"])
                db.add(tag)
                db.flush()

            new_image_tag = ImageTag(image_id=image.id, tag_id=tag.id)
            db.add(new_image_tag)
            tags.add(tag)

    db.commit()

    return DiaryResponse(
        id=new_diary.id,
        date=new_diary.date,
        image_urls=image_urls,
        emotions=emotions,
        text=new_diary.text if new_diary.text else "",  # ✅ Pydantic 오류 방지
        tags=[{"id": tag.id, "type": tag.type, "tag_name": tag.tag_name}
              for tag in tags],
        created_at=new_diary.created_at,
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
