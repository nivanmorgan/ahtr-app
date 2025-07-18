from logging.config import fileConfig
import os

from sqlalchemy import engine_from_config, pool
from alembic import context

from app.db import Base, POSTGRES_URL
from app import models  # ensure models are imported

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Override database URL from environment or default
config.set_main_option('sqlalchemy.url', POSTGRES_URL)

target_metadata = Base.metadata

def run_migrations_offline():
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online():
    connectable = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )

        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
