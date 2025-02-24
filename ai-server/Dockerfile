# 1️⃣ 베이스 이미지 설정 (Python 3.10 사용)
FROM python:3.10

# 2️⃣ 시스템 패키지 설치 (OpenCV 실행을 위한 필수 라이브러리 추가)
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 && \
    rm -rf /var/lib/apt/lists/*

# 3️⃣ TensorFlow GPU 비활성화 (CPU에서 실행)
ENV CUDA_VISIBLE_DEVICES="-1"

# 4️⃣ 작업 디렉토리 설정
WORKDIR /app

# 5️⃣ 환경 변수 설정 (Python 모듈 검색 경로 추가)
ENV PYTHONPATH="/app"

# 6️⃣ 필요한 패키지 설치
COPY requirements.txt . 
RUN pip install --no-cache-dir -r requirements.txt

# 7️⃣ DeepFace 캐시 디렉토리 설정 (모델 가중치 다운로드 방지)
RUN mkdir -p /root/.deepface/weights

# 8️⃣ 앱 코드 복사
COPY . .

# 9️⃣ FastAPI 서버 실행
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001", "--reload"]