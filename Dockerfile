FROM python:3.12-slim AS base

# env hygiene
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# System deps (only what we need)
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 10001 appuser

WORKDIR /app
COPY app/requirements.txt /app/
RUN python -m pip install --upgrade pip && pip install -r requirements.txt

COPY app/ /app/

# Drop root
USER appuser

# Cloud Run expects port 8080
EXPOSE 8080

# Gunicorn entrypoint
CMD ["gunicorn", "-c", "gunicorn_conf.py", "main:app"]
