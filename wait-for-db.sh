#!/bin/sh
set -e

# Derive DB connection details; allow composing POSTGRES_URL from parts
DB_HOST=${DB_HOST:-}
DB_PORT=${DB_PORT:-}
DB_NAME=${DB_NAME:-}
DB_USER=${DB_USER:-}
DB_PASSWORD=${DB_PASSWORD:-}

if [ -n "$POSTGRES_URL" ] && { [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ]; }; then
  PYCODE='import os,sys
from urllib.parse import urlparse
u=os.environ.get("POSTGRES_URL")
if not u:
    print("")
    sys.exit(0)
p=urlparse(u)
host=p.hostname or ""
port=str(p.port or 5432)
print(f"{host}:{port}")'
  HP=$(python -c "$PYCODE")
  DB_HOST=${DB_HOST:-$(echo "$HP" | cut -d: -f1)}
  DB_PORT=${DB_PORT:-$(echo "$HP" | cut -d: -f2)}
fi

: "${DB_HOST:=db}"
: "${DB_PORT:=5432}"

# Compose POSTGRES_URL if missing and parts are present
if [ -z "$POSTGRES_URL" ] && [ -n "$DB_HOST" ] && [ -n "$DB_NAME" ] && [ -n "$DB_USER" ] && [ -n "$DB_PASSWORD" ]; then
  export POSTGRES_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
fi

echo "Waiting for Postgres at ${DB_HOST}:${DB_PORT}..."
until nc -z "$DB_HOST" "$DB_PORT"; do
  sleep 0.3
done

echo "Running migrations..."
alembic upgrade head || { echo "Alembic migration failed" >&2; exit 1; }

echo "Postgres ready. Starting app..."
exec "$@"
