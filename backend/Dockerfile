# --- Stage 1: builder — install dependency di sini, image ini gak dipakai jadi image final ---
FROM python:3.12-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# --- Stage 2: runtime — image final, cuma bawa yang perlu jalanin app ---
FROM python:3.12-slim

# Update OS packages untuk mendapatkan security patches Debian
RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

# Bikin user non-root
RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app
COPY --from=builder /root/.local /home/appuser/.local
COPY . .

RUN chown -R appuser:appuser /app
USER appuser

ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
