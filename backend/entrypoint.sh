#!/bin/sh

echo "⏳ Waiting for PostgreSQL to be ready..."

# 환경 변수 설정
DB_HOST="${POSTGRES_HOST:-db}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_USER="${POSTGRES_USER:-mindlog}"
DB_NAME="${POSTGRES_DB:-mindlog_db}"

# PostgreSQL이 실행될 때까지 대기
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER"; do
  sleep 1
done

echo "✅ PostgreSQL is ready! Running database migrations..."
alembic upgrade head  # ✅ Alembic 마이그레이션 실행

echo "🚀 Starting FastAPI backend..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
