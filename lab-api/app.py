import os
import random
from datetime import datetime, timezone

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware


app = FastAPI(title="CTFd Local Lab API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ],
    allow_credentials=True,
    allow_methods=["GET"],
    allow_headers=["*"],
)

active_labs = {}


def client_key(request: Request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for", "")
    if forwarded_for:
        return forwarded_for.split(",", maxsplit=1)[0].strip()

    if request.client:
        return request.client.host

    return "local-dev"


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/spawn")
def spawn(request: Request):
    key = client_key(request)

    if key not in active_labs:
        ctid = random.randint(501, 599)
        active_labs[key] = {
            "status": "started",
            "ctid": ctid,
            "ip_address": "127.0.0.1",
            "terminal_url": os.getenv("LAB_TERMINAL_URL", "http://localhost:7681"),
            "expires_in": os.getenv("LAB_EXPIRES_IN", "2 hours"),
            "created_at": datetime.now(timezone.utc).isoformat(),
            "mode": "local-dev",
        }

    return active_labs[key]
