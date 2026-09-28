# ═══════════════════════════════════════════════════════════════════## CP2 — Containerization (production-ready)
#
#   [x] Multi-stage: `builder` cài dependency, `runtime` chỉ nhận kết quả
#   [x] Base image python:3.11-slim ở cả hai stage
#   [x] COPY requirements.txt + pip install TRƯỚC khi COPY source (layer cache)
#   [x] Chạy bằng user thường `appuser` (uid 10001), không phải root
#   [x] HEALTHCHECK gọi /health
#   [x] Đọc cổng từ $PORT (mặc định 8000)
#
# Build:  docker build -t day12-agent:prod .
# Kiểm tra: pytest tests/test_cp2.py -v
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — được phép nặng, bị vứt đi sau khi build ─────
FROM python:3.11-slim AS builder

WORKDIR /build

# Chỉ copy requirements.txt: sửa code không làm mất cache của layer pip
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: runtime — thứ duy nhất trở thành image ─────────────────
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app

RUN useradd --create-home --uid 10001 appuser

# Chỉ mang sang thư viện đã cài, không mang theo cache/compiler của builder
COPY --from=builder /install /usr/local

# Source code copy SAU cùng — layer thay đổi thường xuyên nhất.
# Cố ý để file thuộc root (không --chown): appuser đọc được nhưng không sửa
# được code — app bị chiếm quyền cũng không ghi đè được chính nó.
COPY app ./app
COPY utils ./utils

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import os, urllib.request as u; u.urlopen('http://127.0.0.1:%s/health' % os.getenv('PORT', '8000'), timeout=4)" || exit 1

# `sh -c` để shell nội suy ${PORT}; `exec` để uvicorn thay thế shell thành
# PID 1 và nhận SIGTERM trực tiếp khi platform tắt container (cần cho CP4)
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
