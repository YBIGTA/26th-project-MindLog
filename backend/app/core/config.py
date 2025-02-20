import os
from dotenv import load_dotenv

load_dotenv()

DB_USER = os.getenv("POSTGRES_USER", "mindlog")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "securepassword")
DB_HOST = os.getenv("POSTGRES_HOST", "db")  # Docker 내부에서는 'db'
DB_PORT = os.getenv("POSTGRES_PORT", "5432")
DB_NAME = os.getenv("POSTGRES_DB", "mindlog_db")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
