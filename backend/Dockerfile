# Python 이미지 선택
FROM python:3.9

# 작업 디렉토리 설정
WORKDIR /app

# 필수 패키지 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 앱 소스 코드 복사
COPY . .

# 실행 권한 부여
RUN chmod +x /app/entrypoint.sh

# 컨테이너 실행 시 entrypoint.sh 실행
CMD ["/app/entrypoint.sh"]
