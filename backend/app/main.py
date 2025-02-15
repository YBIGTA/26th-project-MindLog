from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth, diary, music
from app.database import Base, engine

# ✅ DB 테이블 자동 생성 (개발용, Alembic을 사용할 경우 생략 가능)
Base.metadata.create_all(bind=engine)

# ✅ FastAPI 앱 초기화
app = FastAPI(title="Mindlog API",
              description="Emotion-based Diary & Music Recommendation", version="1.0")

# ✅ CORS 설정 (프론트엔드에서 API 호출 가능하도록)
origins = [
    "http://localhost:3000",  # React, Next.js 프론트엔드 (개발 환경)
    "http://127.0.0.1:3000",
    "https://mindlog.com",  # 실제 배포된 프론트엔드
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],  # 모든 HTTP 메서드 허용 (GET, POST, PUT, DELETE)
    allow_headers=["*"],  # 모든 HTTP 헤더 허용
)

# ✅ 라우터 등록 (API 엔드포인트 설정)
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
# app.include_router(diary.router, prefix="/diary", tags=["Diary"])
# app.include_router(music.router, prefix="/music", tags=["Music"])

# ✅ 기본 엔드포인트


@app.get("/")
def read_root():
    return {"message": "Welcome to Mindlog API!"}
