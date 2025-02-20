# Python 이미지 선택
FROM python:3.9

# 시스템 패키지 업데이트 & PostgreSQL 클라이언트 설치
RUN apt-get update && apt-get install -y postgresql-client

# 작업 디렉토리 설정
WORKDIR /app

# 필수 패키지 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# entrypoint.sh 복사 후 실행 권한 부여
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 컨테이너 실행 시 entrypoint.sh 실행
CMD ["/app/entrypoint.sh"]
