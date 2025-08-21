# Use Python 3.11 slim image for smaller size
FROM python:3.11-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port (Cloud Run will override this)
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')" || exit 1

# Start the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]



# FROM python:3.12-slim AS base

# # env hygiene
# ENV PYTHONDONTWRITEBYTECODE=1 \
#     PYTHONUNBUFFERED=1 \
#     PIP_NO_CACHE_DIR=1

# # System deps (only what we need)
# RUN apt-get update && apt-get install -y --no-install-recommends \
#       ca-certificates curl \
#     && rm -rf /var/lib/apt/lists/*

# # Create non-root user
# RUN useradd -m -u 10001 appuser

# WORKDIR /app
# COPY app/requirements.txt /app/
# RUN python -m pip install --upgrade pip && pip install -r requirements.txt

# COPY app/ /app/

# # Drop root
# USER appuser

# # Cloud Run expects port 8080
# EXPOSE 8080

# # Gunicorn entrypoint
# CMD ["gunicorn", "-c", "gunicorn_conf.py", "main:app"]
