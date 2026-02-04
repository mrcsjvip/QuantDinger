# QuantDinger single image for Aliyun ACR (root Dockerfile)
# Build: from repo root: docker build -t quantdinger:latest .
# Run: docker run -p 5000:5000 -e DATABASE_URL=... quantdinger:latest
# Frontend is built and served by the backend on the same port.
#
# Base images from 阿里云容器镜像服务 制品中心 (same region as ACR, good network).
# Platform: linux/amd64.

ARG NODE_IMAGE=alibaba-cloud-linux-3-registry.cn-hangzhou.cr.aliyuncs.com/alinux3/node:20.16
ARG PYTHON_IMAGE=alibaba-cloud-linux-3-registry.cn-hangzhou.cr.aliyuncs.com/alinux3/python:3.11.1

# ---------------------------------------------------------------------------
# Stage 1: Build Vue frontend
# ---------------------------------------------------------------------------
FROM --platform=linux/amd64 ${NODE_IMAGE} AS frontend-builder
WORKDIR /app
COPY quantdinger_vue/package*.json ./
RUN npm install --legacy-peer-deps
COPY quantdinger_vue/ .
RUN npm run build

# ---------------------------------------------------------------------------
# Stage 2: Python backend + embed frontend static (Alibaba Cloud Linux 3, dnf)
# ---------------------------------------------------------------------------
FROM --platform=linux/amd64 ${PYTHON_IMAGE}

WORKDIR /app

RUN dnf install -y gcc libffi-devel curl && dnf clean all

COPY backend_api_python/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend_api_python/ .
COPY --from=frontend-builder /app/dist /app/static_web

RUN mkdir -p logs data/memory

EXPOSE 5000

ENV PYTHONUNBUFFERED=1
ENV PYTHON_API_HOST=0.0.0.0
ENV PYTHON_API_PORT=5000

CMD ["python3", "run.py"]
