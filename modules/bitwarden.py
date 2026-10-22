import os
import subprocess
from datetime import datetime

from modules.config import (
    BACKUP_DIR,
    BW_CLIENTID,
    BW_CLIENTSECRET,
    SOURCE_PASSWORD,
    SOURCE_SERVER,
)


async def login():
    subprocess.run(
        ["bw", "logout"],
        capture_output=True,
        text=True,
    )
    os.environ["BW_CLIENTID"] = BW_CLIENTID
    os.environ["BW_CLIENTSECRET"] = BW_CLIENTSECRET

    subprocess.run(
        ["bw", "config", "server", SOURCE_SERVER],
        capture_output=True,
        text=True,
        check=True,
    )
    subprocess.run(
        ["bw", "login", "--apikey", "--raw"],
        capture_output=True,
        text=True,
        check=True,
    )

    result = subprocess.run(
        ["bw", "unlock", SOURCE_PASSWORD, "--raw"],
        capture_output=True,
        text=True,
        check=True,
    )

    source_session = result.stdout.strip()

    subprocess.run(
        ["bw", "sync", "--session", source_session],
        capture_output=True,
        text=True,
        check=True,
    )

    filename = f"bw-{datetime.now().strftime('%Y-%m-%d-%H-%M')}"
    os.makedirs(BACKUP_DIR, exist_ok=True)
    output_dir = (
        f"{BACKUP_DIR}{filename}.json"
        if BACKUP_DIR.endswith("/")
        else f"{BACKUP_DIR}/{filename}.json"
    )

    subprocess.run(
        [
            "bw",
            "--session",
            source_session,
            "export",
            "--format",
            "encrypted_json",
            "--password",
            SOURCE_PASSWORD,
            "--output",
            output_dir,
        ],
        capture_output=True,
        text=True,
        check=True,
    )

    return output_dir
