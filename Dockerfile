# ---- Stage 1: Fetch the Bitwarden CLI binary ----
FROM debian:bookworm-slim AS bw-cli
ARG BW_CLI_VERSION=2024.10.0
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip ca-certificates \
    && curl -fsSL -o /tmp/bw.zip \
        "https://github.com/bitwarden/clients/releases/download/cli-v${BW_CLI_VERSION}/bw-linux-${BW_CLI_VERSION}.zip" \
    && unzip /tmp/bw.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/bw \
    && rm -rf /tmp/bw.zip /var/lib/apt/lists/*

# ---- Stage 2: Install Python packages ----
FROM python:3.13-slim AS builder
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Stage 3: Final runtime image ----
FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app

COPY --from=bw-cli /usr/local/bin/bw /usr/local/bin/bw
COPY --from=builder /install /usr/local

COPY main.py ./
COPY modules ./modules

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
