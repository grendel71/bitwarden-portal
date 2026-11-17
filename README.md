# Bitwarden Portal

A small service that backs up a Bitwarden or Vaultwarden vault to a password-protected encrypted JSON file. It exposes an HTTP API that enqueues backup jobs, which a background worker runs using the Bitwarden CLI.

The export uses the Bitwarden CLI's native encrypted export (`--format encrypted_json`), so plaintext vault data is never written to disk.

## Architecture

Three services run together via Docker Compose:

- `bitwarden_portal` — FastAPI app that exposes the HTTP API and enqueues backup jobs.
- `worker` — RQ worker that runs the backup jobs.
- `redis` — job queue that connects the API and the worker.

```
POST /api/queueBackup ──► FastAPI ──► Redis (RQ) ──► worker ──► bw export ──► ./backups
```

## Quick start

### 1. Create a `.env` file

```bash
cp .env.example .env
```

Fill in the required variables (see [Environment Variables](#environment-variables)).

### 2. Build and start

```bash
docker compose up -d --build
```

### 3. Trigger a backup

```bash
curl -X POST http://localhost:4200/api/queueBackup
```

The response contains the job ID:

```json
{"job_id": "8f4e..."}
```

Backups are written to `./backups/` on the host (mounted at `/app/backups` in the containers).

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SOURCE_ACCOUNT` | Email for the vault account |
| `SOURCE_PASSWORD` | Master password for the vault. Also used to encrypt the exported JSON |
| `SOURCE_CLIENT_ID` | API key client ID — found in Account Settings → Security → Keys |
| `SOURCE_CLIENT_SECRET` | API key client secret |
| `SOURCE_SERVER` | Bitwarden/Vaultwarden server URL |
| `BACKUP_DIR` | Directory where backup files are written (inside the container), e.g. `/app/backups` |
| `REDIS_HOST` | Redis host. Inside Docker use the service name `redis` |
| `REDIS_PORT` | Redis port (default `6379`) |

All of the above are required — the app fails to start if any is missing.

## API

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/queueBackup` | Enqueue a backup job. Returns `{"job_id": "..."}` |
| `GET` | `/api/jobs/{job_id}` | Get job status. Returns `{"status": "...", "result": ...}`; `404` if the job does not exist |
| `GET` | `/api/health` | Health check. Returns `{"status": "ok"}` |

There is no built-in scheduler. Trigger backups by calling `/api/queueBackup` on your own schedule (for example, a host cron job).

## Recovery

To restore from a backup:

```bash
bw import encrypted_json bw-2026-11-17-00-00.json
```

You will be prompted for the password — this is your master password (`SOURCE_PASSWORD`). Works on any Bitwarden or Vaultwarden instance.

Backup files use the format `bw-YYYY-MM-DD-HH-MM.json`.

## Development

Run the API locally with a local Redis:

```bash
pip install -r requirements.txt
uvicorn main:app --reload
```

A Nix development shell is also provided (`flake.nix`) with Python 3.13.
