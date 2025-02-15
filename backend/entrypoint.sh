#!/bin/sh
echo "⏳ Waiting for PostgreSQL to be ready..."
until pg_isready -h db -p 5432 -U user; do
  sleep 1
done
echo "✅ PostgreSQL is ready! Starting the backend..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
