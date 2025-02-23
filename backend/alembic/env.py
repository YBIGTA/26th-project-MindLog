import sys
import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from alembic import context

# ✅ Alembic이 `app`을 찾을 수 있도록 강제 설정
sys.path.insert(0, os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..")))

# ✅ 기존 models에서 MetaData 불러오기
try:
    from app.database import Base  # 🚀 여기서 오류가 나던 부분 해결됨!
except ModuleNotFoundError as e:
    print(f"⚠️ ModuleNotFoundError: {e}")
    print("📌 해결 방법: 'sys.path'에 프로젝트 루트 경로를 추가했는지 확인하세요!")

# Alembic 설정 로드
config = context.config

# ✅ 로그 설정 파일 로드 (alembic.ini 사용)
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# ✅ target_metadata 설정 (테이블 자동 감지를 위해)
target_metadata = Base.metadata  # 기존 코드에서 `None` → `Base.metadata` 로 수정!

# ==============================
# ✅ 마이그레이션 실행 함수 정의
# ==============================


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,  # ✅ MetaData 적용
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, target_metadata=target_metadata  # ✅ MetaData 적용
        )

        with context.begin_transaction():
            context.run_migrations()


# ✅ 마이그레이션 모드 실행
if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
