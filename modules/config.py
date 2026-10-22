import os

from dotenv import load_dotenv

load_dotenv()

REQUIRED_ENV = [
    "SOURCE_CLIENT_ID",
    "SOURCE_CLIENT_SECRET",
    "BACKUP_DIR",
    "SOURCE_SERVER",
    "SOURCE_ACCOUNT",
    "SOURCE_PASSWORD",
]


for var in REQUIRED_ENV:
    if var not in os.environ:
        raise OSError(f"Required environment variable {var} is missing.")


BW_CLIENTID = os.environ.get("SOURCE_CLIENT_ID")
BW_CLIENTSECRET = os.environ.get("SOURCE_CLIENT_SECRET")
SOURCE_ACCOUNT = os.environ.get("SOURCE_ACCOUNT")
SOURCE_SERVER = os.environ.get("SOURCE_SERVER")
BACKUP_DIR = os.environ.get("BACKUP_DIR")
BACKUP = BACKUP_DIR
SOURCE_PASSWORD = os.environ.get("SOURCE_PASSWORD")
