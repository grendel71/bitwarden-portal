# ---- Stage 1: Fetch the Bitwarden CLI binary ----
# Uses the Python standard library to download and unzip, so the build does not
# need apt-get (and does not need access to deb.debian.org).
FROM python:3.13-slim AS bw-cli
ARG BW_CLI_VERSION=2024.10.0
RUN python -c "import io, os, urllib.request, zipfile; v = os.environ['BW_CLI_VERSION']; url = f'https://github.com/bitwarden/clients/releases/download/cli-v{v}/bw-linux-{v}.zip'; zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(url).read())).extract('bw', '/usr/local/bin')" \
    && chmod +x /usr/local/bin/bw

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
