FROM python:3.11-slim

ARG S3_BUCKET_NAME
ARG POSTGRES_URL

ENV PYTHONUNBUFFERED=1 \
    S3_BUCKET_NAME=${S3_BUCKET_NAME} \
    POSTGRES_URL=${POSTGRES_URL}

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create a non-root user
RUN adduser --disabled-password --gecos "" appuser

COPY . .
RUN chown -R appuser:appuser /app

USER appuser

CMD ["gunicorn", "app.main:app", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000"]
