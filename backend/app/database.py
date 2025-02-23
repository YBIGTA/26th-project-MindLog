import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# ✅ .env 파일 로드
load_dotenv()

# ✅ 환경 변수에서 DATABASE_URL 가져오기
DATABASE_URL = os.getenv("DATABASE_URL")

# ✅ SQLAlchemy 엔진 생성
engine = create_engine(DATABASE_URL)

# ✅ 세션 팩토리 생성
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# ✅ ORM 베이스 클래스
Base = declarative_base()

# ✅ DB 세션 의존성 주입 함수


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
