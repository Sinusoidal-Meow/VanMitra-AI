FROM python:3.11-slim

WORKDIR /app

# System: Tesseract OCR + Marathi + Hindi language packs + GDAL for rasterio (Module B)
RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-mar \
    tesseract-ocr-hin \
    libgl1 \
    libgdal-dev \
    gdal-bin \
    libspatialindex-dev \
    && rm -rf /var/lib/apt/lists/*

# Required for rasterio to locate the GDAL native bindings
ENV GDAL_CONFIG=/usr/bin/gdal-config

# Python dependencies
COPY requirements*.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# App source, migrations and scripts
COPY app/ ./app/
COPY migrations/ ./migrations/
COPY alembic.ini ./
COPY scripts/ ./scripts/

# AI config assets (evidence weights, rejection classes, etc.)
COPY assets/ ./assets/

EXPOSE 8000

# Railway injects $PORT — use it if set, otherwise default 8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
