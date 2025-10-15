# syntax=docker/dockerfile:1.7

# Base image with Python
FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# System deps (cairo libs for cairosvg, etc.)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl git \
       libcairo2 libpango-1.0-0 libpangocairo-1.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /docs

# Only install Python deps first for better layer caching
COPY requirements.txt ./
RUN python -m pip install --upgrade pip \
    && python -m pip install -r requirements.txt

# --- Builder stage: build static site ---
FROM base AS builder
COPY . .
RUN mkdocs build

# --- Production stage: serve static site with nginx ---
FROM nginx:alpine AS prod
COPY --from=builder /docs/site /usr/share/nginx/html

# --- Dev stage: live-reload server ---
FROM base AS dev
WORKDIR /docs
COPY . .
EXPOSE 8000
CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]
