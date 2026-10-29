import asyncio

from fastapi import FastAPI, HTTPException
from redis import Redis
from rq import Queue, Retry
from rq.exceptions import NoSuchJobError
from rq.job import Job

from modules.bitwarden import login
from modules.config import REDIS_HOST, REDIS_PORT

app = FastAPI()


redis_conn = Redis(host=REDIS_HOST, port=REDIS_PORT)
queue = Queue("default", connection=redis_conn)


@app.post("/api/queueBackup")
async def queue_backup():
    job = await asyncio.to_thread(
        queue.enqueue,
        login,
        job_timeout=300,
        retry=Retry(max=3),
    )
    return {"job_id": job.id}


@app.get("/api/jobs/{job_id}")
async def get_job_status(job_id: str):
    try:
        job = Job.fetch(job_id, connection=redis_conn)
    except NoSuchJobError:
        raise HTTPException(status_code=404, detail="No such job")
    return {
        "status": job.get_status(),
        "result": job.return_value() if job.is_finished else None,
    }


@app.get("/api/health")
async def health():
    return {"status": "ok"}
