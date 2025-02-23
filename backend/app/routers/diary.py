import uuid
import requests
import io
import piexif
from PIL import Image as PILImage, ExifTags
from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile, Form
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.models.diary_model import Diary, Image, Tag, ImageTag
from app.schemas.diary_schema import DiaryResponse
from app.routers.auth import get_current_user
from app.core.config import s3_client, settings  # ✅ S3 클라이언트 임포트
from datetime import datetime, timedelta, timezone

router = APIRouter(prefix="/diary", tags=["Diary"])

AI_SERVER_URL = "http://192.168.0.16:8001/ai/generate-tags"  # ✅ AI 서버 URL


def upload_image_to_s3(image: UploadFile, s3_filename: str) -> str:
    """GPS 메타데이터 포함하여 S3 업로드"""

    # ✅ 이미지 로드
    image_data = image.file.read()
    image.file.seek(0)  # 읽기 위치 리셋
    pil_image = PILImage.open(io.BytesIO(image_data))

    # ✅ EXIF 정보 로드
    try:
        exif_dict = piexif.load(image_data)
        gps_data = exif_dict.get("GPS", {})

        if gps_data:
            print("✅ GPS 정보 있음:", gps_data)
        else:
            print("❌ GPS 정보 없음")

        exif_bytes = piexif.dump(exif_dict)

    except Exception as e:
        print("❌ EXIF 데이터 없음:", e)
        exif_bytes = None

    # ✅ EXIF 정보 유지하면서 JPEG로 변환
    buffer = io.BytesIO()
    if exif_bytes:
        pil_image.save(buffer, format="JPEG", exif=exif_bytes)
    else:
        pil_image.save(buffer, format="JPEG")
    buffer.seek(0)

    # ✅ S3 업로드
    s3_client.upload_fileobj(
        buffer,
        settings.AWS_S3_BUCKET_NAME,
        s3_filename,
        ExtraArgs={"ContentType": "image/jpeg"},  # ✅ MIME 타입 유지
    )

    return f"https://{settings.AWS_S3_BUCKET_NAME}.s3.amazonaws.com/{s3_filename}"


@router.post("/", response_model=DiaryResponse, status_code=status.HTTP_201_CREATED)
async def create_diary(
    date: str = Form(...),
    emotions: List[str] = Form(...),
    text: Optional[str] = Form(None),
    images: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    new_diary = Diary(
        id=uuid.uuid4(),
        user_id=user.id,
        date=date,
        emotions=", ".join(emotions),
        text=text if text else "",
    )
    db.add(new_diary)
    db.flush()

    image_urls = []
    uploaded_images = []

    # ✅ 이미지 S3 업로드 (EXIF 유지)
    for image in images:
        file_extension = image.filename.split(".")[-1]
        s3_filename = f"{uuid.uuid4()}.{file_extension}"

        s3_url = upload_image_to_s3(image, s3_filename)
        image_urls.append(s3_url)

        new_image = Image(
            id=uuid.uuid4(), diary_id=new_diary.id, image_url=s3_url)
        db.add(new_image)
        uploaded_images.append(new_image)

    db.commit()
    db.refresh(new_diary)

    # ✅ AI 서버에 이미지 URL 전달하여 태그 요청
    try:
        ai_response = requests.post(
            AI_SERVER_URL, json={"image_urls": image_urls})
        ai_results = ai_response.json().get("results", [])
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 서버 요청 실패: {str(e)}")

    tags = set()

    # ✅ AI 서버 응답을 기반으로 태그 매핑
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
        text=new_diary.text,
        tags=[{"id": tag.id, "type": tag.type, "tag_name": tag.tag_name}
              for tag in tags],
        created_at=new_diary.created_at,
    )


@router.get("/", response_model=List[DiaryResponse])
def get_diary_list(
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
    year: Optional[int] = None,
    month: Optional[int] = None,
):
    """다이어리 목록 조회 (쿼리 없으면 최신 10개, 특정 연/월 지정 가능, 최대 33개)"""

    query = db.query(Diary).filter(Diary.user_id == user.id)

    # ✅ 특정 연/월로 필터링
    if year:
        query = query.filter(
            Diary.date >= f"{year}-01-01", Diary.date <= f"{year}-12-31")
    if month:
        query = query.filter(
            Diary.date >= f"{year}-{month:02d}-01", Diary.date <= f"{year}-{month:02d}-31")

    # ✅ 최신순 정렬 후 최대 개수 제한 (기본 10개, 최대 33개)
    diaries = query.order_by(Diary.date.desc()).limit(
        33 if (year or month) else 10).all()

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


@router.get("/grouped-by-person")
def get_diary_grouped_by_person(db: Session = Depends(get_db), user=Depends(get_current_user)):
    """인물 태그 기준으로 다이어리 그룹화"""
    people = (
        db.query(Tag.tag_name)
        .join(ImageTag, Tag.id == ImageTag.tag_id)  # ✅ 태그와 이미지 연결
        .join(Image, Image.id == ImageTag.image_id)  # ✅ 이미지와 다이어리 연결
        .join(Diary, Diary.id == Image.diary_id)  # ✅ 다이어리와 사용자 연결
        # ✅ 현재 로그인한 사용자만 필터
        .filter(Diary.user_id == user.id, Tag.type == "인물")
        .distinct()
        .all()
    )

    response = []
    for person in people:
        person_name = person[0]

        diaries = (
            db.query(Diary)
            .join(Image, Diary.id == Image.diary_id)  # ✅ 다이어리와 이미지 연결
            .join(ImageTag, Image.id == ImageTag.image_id)  # ✅ 이미지와 태그 연결
            .join(Tag, ImageTag.tag_id == Tag.id)  # ✅ 태그와 연결
            .filter(Diary.user_id == user.id, Tag.tag_name == person_name)
            .order_by(Diary.date.desc())
            .all()
        )

        print(f"📌 Diaries for {person_name}: {len(diaries)}")

        if diaries:
            thumbnail_url = diaries[0].images[0].image_url if diaries[0].images else None
            response.append({
                "person_name": person_name,
                "thumbnail_url": thumbnail_url,
                "diary_count": len(diaries)
            })

    return {"people": response}


@router.get("/recent-activity")
def get_recent_activity(db: Session = Depends(get_db), user=Depends(get_current_user)):
    """최근 50일 동안의 다이어리 작성 여부 및 첫 번째 감정 반환 (오늘 포함)"""

    # ✅ 현재 시간 (UTC+9, 한국 표준시)
    korea_tz = timezone(timedelta(hours=9))
    today = datetime.now(korea_tz).date()  # ✅ 한국 시간 기준 오늘 날짜

    start_date = today - timedelta(days=49)  # ✅ 50일 전부터 조회

    # ✅ DB에서 해당 기간 동안의 다이어리 데이터 가져오기 (DATE 타입 비교)
    diaries = (
        db.query(Diary.date, Diary.emotions)
        .filter(Diary.user_id == user.id, Diary.date >= start_date.strftime("%Y-%m-%d"))
        .order_by(Diary.date.desc())
        .all()
    )

    # ✅ 날짜별 다이어리 여부 및 첫 번째 감정 매핑
    diary_map = {diary.date.strftime(
        "%Y-%m-%d"): (diary.emotions.split(", ")[0] if diary.emotions else None) for diary in diaries}

    recent_activity = []
    for i in range(50):  # ✅ 50일치 데이터 조회 (오늘 포함)
        date_str = (today - timedelta(days=i)).strftime("%Y-%m-%d")
        recent_activity.append({
            "date": date_str,
            "has_diary": date_str in diary_map,
            "emotion": diary_map.get(date_str, None)
        })

    return {"recent_activity": recent_activity}


@router.get("/by-person/{person_name}")
def get_diary_by_person(person_name: str, db: Session = Depends(get_db), user=Depends(get_current_user)):
    """특정 인물 태그가 포함된 다이어리 목록 조회"""
    diaries = (
        db.query(Diary)
        .join(Image, Diary.id == Image.diary_id)  # ✅ 다이어리와 이미지 연결
        .join(ImageTag, Image.id == ImageTag.image_id)  # ✅ 이미지와 태그 연결
        .join(Tag, ImageTag.tag_id == Tag.id)  # ✅ 태그와 연결
        .filter(Diary.user_id == user.id, Tag.tag_name == person_name)
        .order_by(Diary.date.desc())
        .all()
    )

    response = []
    for diary in diaries:
        # ✅ diary와 연결된 태그 목록 가져오기
        tags = (
            db.query(Tag)
            .join(ImageTag, Tag.id == ImageTag.tag_id)
            .join(Image, Image.id == ImageTag.image_id)
            .filter(Image.diary_id == diary.id)
            .all()
        )

        response.append({
            "id": str(diary.id),
            "date": diary.date,
            "thumbnail_url": diary.images[0].image_url if diary.images else None,
            "text": diary.text[:100],  # 최대 100자 제한
            "emotions": diary.emotions.split(", ") if diary.emotions else [],
            # ✅ 태그 리스트 수정
            "tags": [{"type": tag.type, "tag_name": tag.tag_name} for tag in tags]
        })

    return {"person_name": person_name, "diaries": response}


@router.get("/{diary_id}")
def get_diary(diary_id: uuid.UUID, db: Session = Depends(get_db), user=Depends(get_current_user)):
    """UUID 기반 특정 다이어리 조회"""
    diary = db.query(Diary).filter(Diary.id == diary_id,
                                   Diary.user_id == user.id).first()
    if not diary:
        raise HTTPException(status_code=404, detail="다이어리를 찾을 수 없습니다.")

    return DiaryResponse(
        id=diary.id,
        date=diary.date,
        image_urls=[image.image_url for image in diary.images],
        emotions=diary.emotions.split(", ") if diary.emotions else [],
        text=diary.text,
        tags=[{"id": tag.id, "type": tag.type, "tag_name": tag.tag_name}
              for tag in diary.tags],
        created_at=diary.created_at
    )
