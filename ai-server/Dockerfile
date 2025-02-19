# 1️⃣ 베이스 이미지 설정 (Python 3.10 사용)
FROM python:3.10

# 2️⃣ 작업 디렉토리 설정
WORKDIR /app

# 3️⃣ 필요한 패키지 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4️⃣ 앱 코드 복사
COPY . .

# 5️⃣ FastAPI 서버 실행
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]