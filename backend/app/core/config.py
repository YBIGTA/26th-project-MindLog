import os
from dotenv import load_dotenv
import boto3

load_dotenv()

DB_USER = os.getenv("POSTGRES_USER", "mindlog")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "securepassword")
DB_HOST = os.getenv("POSTGRES_HOST", "db")  # Docker 내부에서는 'db'
DB_PORT = os.getenv("POSTGRES_PORT", "5432")
DB_NAME = os.getenv("POSTGRES_DB", "mindlog_db")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"


class Settings:
    AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
    AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
    AWS_REGION = os.getenv("AWS_REGION", "ap-southeast-2")  # ✅ 기본 리전: 서울
    AWS_S3_BUCKET_NAME = os.getenv("AWS_S3_BUCKET_NAME")


settings = Settings()

# AWS S3 설정
s3_client = boto3.client(
    "s3",
    aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
    aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    region_name=settings.AWS_REGION,
)

S3_BUCKET = settings.AWS_S3_BUCKET_NAME
