import uuid
import random
from datetime import datetime, timedelta
from faker import Faker
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.diary_model import Diary, Image, Tag, ImageTag
from app.models.user_model import User

fake = Faker()

# ✅ 사용할 감정 목록 (랜덤 선택)
EMOTIONS = ["기쁨", "신뢰", "긴장", "놀람", "슬픔", "혐오", "격노", "열망"]

# ✅ 고정된 태그 타입 및 랜덤 태그 목록
TAGS_BY_TYPE = {
    "인물": ["친구", "가족", "동료", "연인"],
    "장소": ["카페", "공원", "학교", "회사", "집"],
    "지역": ["서울", "부산", "대구", "광주", "제주"]
}

# ✅ S3에 업로드된 이미지 URL 리스트 (랜덤 선택)
DUMMY_IMAGE_URLS = [
    "https://mindlog-images.s3.ap-southeast-2.amazonaws.com/04551d87-4aaa-4dff-bcc7-36d09b3ddbc8.jpg",
    "https://mindlog-images.s3.ap-southeast-2.amazonaws.com/bfc9a9cb-990f-4a2f-9b16-32ab3ae2bc58.jpg",
    "https://mindlog-images.s3.ap-southeast-2.amazonaws.com/d0895dfd-5e10-4cd9-8e72-718e204c327c.jpg",
    "https://mindlog-images.s3.ap-southeast-2.amazonaws.com/e30d62d1-8ba7-424d-beb0-ce5b6f373320.jpg",
    "https://mindlog-images.s3.ap-southeast-2.amazonaws.com/06932223-b82c-45e1-ae44-0c624b114e7c.jpg",
    "https://mindlog-images.s3.ap-southeast-2.amazonaws.com/0a918f00-2118-4f98-adb0-8f6e88001135.jpg",
    "https://mindlog-images.s3.ap-southeast-2.amazonaws.com/73d3ede6-956b-43b2-ab81-02e25a616890.jpg",
]


def create_dummy_data(db: Session, num_diaries=10):
    """1명의 사용자 + 다이어리 + 감정 + 태그 삽입"""

    # ✅ 1️⃣ 가상 사용자 생성 (이메일 중복 확인)
    user = db.query(User).filter(User.email == "dummyuser@example.com").first()
    if not user:
        user = User(
            id=str(uuid.uuid4()),
            email="dummyuser@example.com",
            username="test_user",
            password="dummy_password",  # 🔥 단순 문자열 비밀번호 저장
            created_at=datetime.now(),
        )
        db.add(user)
        db.commit()

    print(f"✅ 사용자 생성 완료: {user.username} ({user.email})")

    # ✅ 2️⃣ 여러 개의 다이어리 생성
    for _ in range(num_diaries):
        diary = Diary(
            id=str(uuid.uuid4()),
            user_id=user.id,
            date=(datetime.now() - timedelta(days=random.randint(1, 365))
                  ).strftime("%Y-%m-%d"),
            emotions=", ".join(random.sample(
                EMOTIONS, k=random.randint(1, 3))),
            text=fake.sentence(nb_words=10),
            created_at=datetime.now(),
        )
        db.add(diary)
        db.flush()  # 다이어리 ID 확보

        # ✅ 3️⃣ 랜덤 이미지 선택하여 다이어리에 추가
        image_url = random.choice(DUMMY_IMAGE_URLS)
        image = Image(id=str(uuid.uuid4()),
                      diary_id=diary.id, image_url=image_url)
        db.add(image)

        # ✅ 4️⃣ 태그 생성 (AI 없이 직접 삽입)
        for tag_type, tag_names in TAGS_BY_TYPE.items():
            if random.random() < 0.7:  # 70% 확률로 해당 타입의 태그 추가
                tag_name = random.choice(tag_names)
                tag = db.query(Tag).filter(
                    Tag.tag_name == tag_name, Tag.type == tag_type).first()
                if not tag:
                    tag = Tag(id=str(uuid.uuid4()),
                              type=tag_type, tag_name=tag_name)
                    db.add(tag)
                    db.flush()

                # ✅ 5️⃣ 태그를 이미지에 연결
                new_image_tag = ImageTag(image_id=image.id, tag_id=tag.id)
                db.add(new_image_tag)

    db.commit()
    print(f"✅ {num_diaries}개의 다이어리 생성 완료!")


if __name__ == "__main__":
    db = next(get_db())  # FastAPI DB 세션 가져오기
    create_dummy_data(db)
