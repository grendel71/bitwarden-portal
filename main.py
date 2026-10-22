import asyncio
import subprocess

from fastapi import FastAPI, HTTPException

from modules.bitwarden import login
from modules.config import BACKUP, BW_CLIENTID, BW_CLIENTSECRET

app = FastAPI()


backup_lock = asyncio.Lock()


@app.post("/api/backup")
async def trig_backuip():
    if backup_lock.locked():
        raise HTTPException(
            status_code=409,
            detail="Backup already in progress",
        )
    async with backup_lock:
        try:
            output = await login()
            return {
                "status": "success",
                "file": output,
            }
        except subprocess.CalledProcessError as e:
            raise HTTPException(
                status_code=500,
                detail=f"CLI backup failed: {e.stderr.strip() or e.stdout.strip()}",
            )
