# Bitwarden Portal

Automate encrypted backups of your Bitwarden or Vaultwarden vault — exports directly to a password-protected encrypted JSON via the Bitwarden CLI. No plaintext ever touches disk.

Works with Bitwarden and Vaultwarden.

## Usage

### 1. Create a `.env` file

```env
CRON_SCHEDULE=0 0 * * *
TZ=Europe/Berlin
ENCRYPTION_PASSWORD=strong-password

SOURCE_ACCOUNT=you@mail.com
SOURCE_PASSWORD=your-password
SOURCE_CLIENT_ID=user.xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
SOURCE_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
SOURCE_SERVER=https://vault.bitwarden.com

PUID=1000
PGID=1000
ENABLE_PRUNING=true
RETENTION_DAYS=30
MIN_FILES=10
```

### 2. Run with Docker Compose

```yaml
services:
  bitwarden-portal:
    image: reaper0x1/bitwarden-portal:latest
    container_name: bitwarden-portal
    env_file: .env
    volumes:
      - ./backups:/app/backups
    restart: unless-stopped
```

```bash
docker compose up -d
```

Backups land in `./backups/source/`.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `CRON_SCHEDULE` | Backup schedule (default: `0 0 * * *` = daily at midnight). Generate at [crontab.guru](https://crontab.guru/) |
| `TZ` | Timezone (e.g. `Europe/Berlin`) |
| `ENCRYPTION_PASSWORD` | Password used to encrypt backup files |
| `SOURCE_ACCOUNT` | Email for the vault |
| `SOURCE_PASSWORD` | Master password for the vault |
| `SOURCE_CLIENT_ID` | API key client ID — found in Account Settings → Security → Keys |
| `SOURCE_CLIENT_SECRET` | API key client secret |
| `SOURCE_SERVER` | Bitwarden/Vaultwarden server URL |
| `PUID` | User ID for file ownership |
| `PGID` | Group ID for file ownership |
| `ENABLE_PRUNING` | Set to `false` to keep all backups (default: `true`) |
| `RETENTION_DAYS` | Delete backups older than this many days |
| `MIN_FILES` | Minimum backups to keep when all are older than retention |

## Recovery

To restore from a backup:

```bash
bw import encrypted_json bw_export_source_2026-01-01_00-00-00.json
```

You'll be prompted for the encryption password. Works on any Bitwarden or Vaultwarden instance.

## Self-Signed Certificates

If your Vaultwarden uses a self-signed certificate, place the `.crt` file in the `certs/` folder before building.
