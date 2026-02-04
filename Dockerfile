# QuantDinger single image for Aliyun ACR (root Dockerfile)
# Build: from repo root: docker build -t quantdinger:latest .
# Run: docker run -p 5000:5000 -e DATABASE_URL=... quantdinger:latest
# Frontend is built and served by the backend on the same port.

# ---------------------------------------------------------------------------
# Stage 1: Build Vue frontend
# ---------------------------------------------------------------------------
FROM node:18-alpine AS frontend-builder
WORKDIR /app
COPY quantdinger_vue/package*.json ./
RUN npm install --legacy-peer-deps
COPY quantdinger_vue/ .
RUN npm run build

# ---------------------------------------------------------------------------
# Stage 2: Python backend + embed frontend static
# ---------------------------------------------------------------------------
FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libffi-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY backend_api_python/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend_api_python/ .
COPY --from=frontend-builder /app/dist /app/static_web

RUN mkdir -p logs data/memory

EXPOSE 5000

ENV PYTHONUNBUFFERED=1
ENV PYTHON_API_HOST=0.0.0.0
ENV PYTHON_API_PORT=5000

CMD ["python", "run.py"]
