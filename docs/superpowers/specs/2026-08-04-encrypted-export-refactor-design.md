# Encrypted Export Refactor

Date: 2026-08-04

## Summary

Refactor `bitwarden-portal.sh` to use the Bitwarden CLI's native `--format encrypted_json --password` export instead of OpenSSL-based encryption. Drop all destination-vault restore logic; keep source backup only.

## Motivation

The current script exports plaintext JSON to a temporary file, then encrypts it with OpenSSL. The Bitwarden CLI supports exporting directly to a password-protected encrypted JSON file, which:

- Never writes plaintext vault data to disk
- Eliminates the OpenSSL dependency
- Simplifies manual recovery (import with `bw import encrypted_json <file>`)

The destination restore functionality is no longer needed — source backup alone is the goal.

## What gets removed

- Entire RESTORE section (dest login, export, item deletion, import)
- `encrypt_file()` and `decrypt_file()` functions
- `cleanup_unencrypted()` function and associated trap
- `/tmp/bitwarden_unencrypted` temporary directory
- All `DEST_*` environment variable usage
- `backups/dest` backup folder
- `openssl` from Dockerfile dependencies
- `.enc` file extension

## What gets changed

**Export command** — replaces two steps with one:

```
# Before
bw export --raw --format json > output.json
openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"$PASS" -in output.json -out output.json.enc

# After
bw export --format encrypted_json --password "$ENCRYPTION_PASSWORD" --output output.json
```

**File naming** — drops `.enc` extension since encryption is internal to the file format.

## What stays

- Cron scheduling via `CRON_SCHEDULE`
- `fix_permissions()` with `PUID`/`PGID`
- `purge_folder()` with `ENABLE_PRUNING`, `RETENTION_DAYS`, `MIN_FILES`
- Source login flow (config server, apikey login, unlock, sync)
- Backup output directory: `backups/source`
- Docker Compose structure

## Impact on env vars

**Removed:** `DEST_ACCOUNT`, `DEST_PASSWORD`, `DEST_CLIENT_ID`, `DEST_CLIENT_SECRET`, `DEST_SERVER`

**Kept:** `CRON_SCHEDULE`, `TZ`, `ENCRYPTION_PASSWORD`, `SOURCE_ACCOUNT`, `SOURCE_PASSWORD`, `SOURCE_CLIENT_ID`, `SOURCE_CLIENT_SECRET`, `SOURCE_SERVER`, `PUID`, `PGID`, `ENABLE_PRUNING`, `RETENTION_DAYS`, `MIN_FILES`

## Manual recovery

Replace the OpenSSL-based flow:

```
# Before
openssl enc -aes-256-cbc -d -pbkdf2 -pass pass:"<pass>" -in backup.enc -out vault.json
```

With:

```
bw import encrypted_json backup.json
# Prompts for the encryption password
```
