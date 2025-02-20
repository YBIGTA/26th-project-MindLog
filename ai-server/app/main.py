from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers.tag import router as tag_router

# ✅ FastAPI 앱 생성
app = FastAPI(title="MindLog AI Server", description="Handles AI-based tagging")

# ✅ CORS 설정 (백엔드와의 통신을 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 필요에 따라 백엔드 도메인만 허용 가능
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ✅ 라우터 등록
app.include_router(tag_router, prefix="/ai")

# ✅ 루트 엔드포인트
@app.get("/")
def root():
    return {"message": "AI Server is running"}
