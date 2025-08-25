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
from app.schemas.diary_schema import DiaryResponse, TagResponse, ImageResponse, PlaceResponse
from app.routers.auth import get_current_user
from app.core.config import s3_client, settings  # ✅ S3 클라이언트 임포트
from datetime import datetime, timedelta, timezone
from calendar import monthrange
from fastapi import Query
from collections import Counter

router = APIRouter(prefix="/diary", tags=["Diary"])

AI_SERVER_URL = "http://ai-server:8001/ai/generate-tags"  # ✅ AI 서버 URL


def extract_gps_from_exif(image_data):
    """EXIF 메타데이터에서 GPS 정보 추출"""
    try:
        exif_dict = piexif.load(image_data)
        gps_data = exif_dict.get("GPS", {})

        if not gps_data or 2 not in gps_data or 4 not in gps_data:
            return None, None

        # ✅ 위도 데이터 추출
        lat_values = gps_data[2]  # (도, 분, 초)
        lat_ref = gps_data.get(1, b'N').decode()  # N(북위) 또는 S(남위)

        # ✅ 경도 데이터 추출
        lon_values = gps_data[4]  # (도, 분, 초)
        lon_ref = gps_data.get(3, b'E').decode()  # E(동경) 또는 W(서경)

        # ✅ 위도 및 경도 변환
        def convert_to_degrees(values):
            return values[0][0] / values[0][1] + \
                values[1][0] / (values[1][1] * 60) + \
                values[2][0] / (values[2][1] * 3600)

        latitude = convert_to_degrees(lat_values)
        longitude = convert_to_degrees(lon_values)

        # ✅ 남반구(S) 또는 서경(W)인 경우 음수 처리
        if lat_ref == 'S':
            latitude = -latitude
        if lon_ref == 'W':
            longitude = -longitude

        return latitude, longitude

    except Exception as e:
        print(f"❌ GPS 데이터 추출 실패: {e}")
        return None, None


def upload_image_to_s3(image: UploadFile, s3_filename: str):
    """GPS 메타데이터 포함하여 S3 업로드 및 GPS 정보 반환"""

    # ✅ 이미지 로드
    image_data = image.file.read()
    image.file.seek(0)  # 읽기 위치 리셋
    pil_image = PILImage.open(io.BytesIO(image_data))

    # ✅ GPS 정보 추출
    latitude, longitude = extract_gps_from_exif(image_data)

    # ✅ EXIF 정보 로드
    try:
        exif_dict = piexif.load(image_data)
        exif_bytes = piexif.dump(exif_dict)
    except Exception:
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
        ExtraArgs={"ContentType": "image/jpeg"},
    )

    return f"https://{settings.AWS_S3_BUCKET_NAME}.s3.amazonaws.com/{s3_filename}", latitude, longitude

@router.post("/upload-temp-images")
async def upload_temp_images(
    images: List[UploadFile] = File(...),
    user=Depends(get_current_user)
):
    """임시 이미지 업로드 - AI 태깅을 위한 S3 URL 생성"""
    uploaded_urls = []
    
    for image in images:
        file_extension = image.filename.split(".")[-1]
        s3_filename = f"temp/{uuid.uuid4()}.{file_extension}"
        
        s3_url, latitude, longitude = upload_image_to_s3(image, s3_filename)
        uploaded_urls.append(s3_url)
    
    return {"image_urls": uploaded_urls}


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

    uploaded_images = []

    # ✅ 이미지 S3 업로드 (EXIF 유지 & GPS 저장)
    for image in images:
        file_extension = image.filename.split(".")[-1]
        s3_filename = f"{uuid.uuid4()}.{file_extension}"

        s3_url, latitude, longitude = upload_image_to_s3(image, s3_filename)

        # ✅ Image 테이블에 GPS 정보 함께 저장
        new_image = Image(
            id=uuid.uuid4(),
            diary_id=new_diary.id,
            image_url=s3_url,
            latitude=latitude,
            longitude=longitude,
        )
        db.add(new_image)
        uploaded_images.append(new_image)

    db.commit()
    db.refresh(new_diary)

    # ✅ AI 서버에 이미지 URL 전달하여 태그 요청
    try:
        ai_response = requests.post(AI_SERVER_URL, json={"image_urls": [
                                    img.image_url for img in uploaded_images]})
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
        images=[
            {
                "id": img.id,
                "image_url": img.image_url,
                "latitude": img.latitude,
                "longitude": img.longitude,
            }
            for img in uploaded_images
        ],
        emotions=emotions,
        text=new_diary.text,
        tags=[{"id": tag.id, "type": tag.type, "tag_name": tag.tag_name}
              for tag in tags],
        created_at=new_diary.created_at,
    )


@router.get("/", response_model=List[DiaryResponse])
def get_diary_list(
    year: Optional[int] = Query(None),
    month: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """최신순으로 다이어리 조회 (쿼리 없으면 최근 10개)"""

    query = db.query(Diary).filter(Diary.user_id == user.id)

    if year and month:
        # ✅ 해당 연도의 월 마지막 날짜 구하기
        last_day_of_month = monthrange(year, month)[1]  # ex) 2월이면 28 or 29

        # ✅ 해당 월에 해당하는 다이어리만 조회
        query = query.filter(
            Diary.date >= f"{year}-{month:02d}-01",
            Diary.date <= f"{year}-{month:02d}-{last_day_of_month}"
        )
        max_items = 33  # ✅ 최대 33개
    else:
        max_items = 10  # ✅ 기본 10개

    # ✅ 최신순 정렬 후 제한 개수 적용
    diaries = query.order_by(Diary.date.desc()).limit(max_items).all()

    response = []
    for diary in diaries:
        # ✅ 이미지 정보 추가 (latitude, longitude 포함)
        images = [
            ImageResponse(
                id=image.id,
                image_url=image.image_url,
                latitude=image.latitude,
                longitude=image.longitude
            ) for image in diary.images
        ]

        # ✅ 태그 정보 추가
        tags = []
        for image in diary.images:
            for image_tag in db.query(ImageTag).filter(ImageTag.image_id == image.id).all():
                tag = db.query(Tag).filter(Tag.id == image_tag.tag_id).first()
                if tag:
                    tags.append(TagResponse(
                        id=tag.id,
                        type=tag.type,
                        tag_name=tag.tag_name
                    ))

        response.append(DiaryResponse(
            id=diary.id,
            date=diary.date,
            images=images,  # ✅ 수정된 부분
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


@router.get("/place", response_model=List[PlaceResponse])
def get_places(db: Session = Depends(get_db), user=Depends(get_current_user)):
    """장소 태그 기준으로 다이어리를 그룹화하여 반환 (최대 4개 그룹)"""

    # ✅ 1. 장소 태그 추출
    place_tags = (
        db.query(Tag.tag_name)
        .filter(Tag.type == "장소")
        .join(ImageTag, Tag.id == ImageTag.tag_id)
        .join(Image, Image.id == ImageTag.image_id)
        .join(Diary, Diary.id == Image.diary_id)
        .filter(Diary.user_id == user.id)
        .all()
    )

    # ✅ 2. 등장 횟수가 많은 상위 4개 장소 태그 선택
    tag_counts = Counter([tag[0] for tag in place_tags])
    top_places = [tag for tag, _ in tag_counts.most_common(4)]

    response = []
    for place in top_places:
        # ✅ 3. 해당 장소 태그가 있는 다이어리 찾기
        diaries = (
            db.query(Diary)
            .join(Image, Diary.id == Image.diary_id)
            .join(ImageTag, Image.id == ImageTag.image_id)
            .join(Tag, Tag.id == ImageTag.tag_id)
            .filter(Diary.user_id == user.id, Tag.tag_name == place)
            .order_by(Diary.date.desc())
            .all()
        )

        # ✅ 4. 다이어리 목록 생성 (위치, 썸네일 포함)
        diary_list = []
        for diary in diaries:
            first_image = db.query(Image).filter(
                Image.diary_id == diary.id).first()
            if first_image:
                diary_list.append({
                    "id": diary.id,
                    "latitude": first_image.latitude,
                    "longitude": first_image.longitude,
                    "thumbnail_url": first_image.image_url
                })

        response.append({
            "category": place,
            "diary_count": len(diary_list),
            "diaries": diary_list
        })

    return response


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


@router.get("/{diary_id}", response_model=DiaryResponse)
def get_diary(diary_id: uuid.UUID, db: Session = Depends(get_db), user=Depends(get_current_user)):
    """UUID 기반 특정 다이어리 조회"""
    diary = db.query(Diary).filter(
        Diary.id == diary_id,
        Diary.user_id == user.id
    ).first()

    if not diary:
        raise HTTPException(status_code=404, detail="다이어리를 찾을 수 없습니다.")

    return DiaryResponse(
        id=diary.id,
        date=diary.date,
        images=[
            ImageResponse(
                id=image.id,
                image_url=image.image_url,
                latitude=image.latitude,
                longitude=image.longitude
            ) for image in diary.images
        ],
        emotions=diary.emotions.split(", ") if diary.emotions else [],
        text=diary.text,
        tags=[
            TagResponse(
                id=tag.id,
                type=tag.type,
                tag_name=tag.tag_name
            ) for tag in diary.tags
        ],
        created_at=diary.created_at
    )
