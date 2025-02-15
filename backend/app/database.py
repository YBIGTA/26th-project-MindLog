from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os

# 환경 변수에서 DATABASE_URL 가져오기
DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://user:password@db:5432/mindlog_db")

# SQLAlchemy 엔진 생성
engine = create_engine(DATABASE_URL)

# 세션 생성
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base 클래스 생성 (모델 정의 시 필요)
Base = declarative_base()

# 데이터베이스 연결 테스트 함수


def test_connection():
    try:
        with engine.connect() as connection:
            print("✅ Database connected successfully!")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")


test_connection()  # 서버 시작 시 DB 연결 확인
