from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers.tag import router as tag_router

app = FastAPI(
    title="Image Tagging API",
    description="장소, 지역, 인물 태그를 생성하는 AI 서버",
    version="1.0.0"
)

# ✅ CORS 설정 (필요 시)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 프로덕션 환경에서는 허용할 도메인만 명시
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ✅ 태깅 API 라우터 등록
app.include_router(tag_router, prefix="/ai", tags=["Tagging"])

# ✅ 루트 경로
@app.get("/")
async def root():
    return {"message": "AI Server is running!"}
