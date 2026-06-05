import os
import random
import subprocess
import time
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.error import URLError
from urllib.request import urlopen

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware


PROXMOX_SSH_TARGET = os.getenv("PROXMOX_SSH_TARGET", "root@192.168.10.2")
PROXMOX_SPAWN_SCRIPT = os.getenv("PROXMOX_SPAWN_SCRIPT", "/root/spawn.sh")
CTID_MIN = int(os.getenv("LAB_CTID_MIN", "501"))
CTID_MAX = int(os.getenv("LAB_CTID_MAX", "599"))
LAB_EXPIRES_SECONDS = int(os.getenv("LAB_EXPIRES_SECONDS", "7200"))
LAB_NETWORK_PREFIX = os.getenv("LAB_NETWORK_PREFIX", "10.50.5")
LAB_TTYD_PORT = int(os.getenv("LAB_TTYD_PORT", "7681"))
LAB_READY_TIMEOUT = int(os.getenv("LAB_READY_TIMEOUT", "60"))
LAB_ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv(
        "LAB_ALLOWED_ORIGINS",
        "http://192.168.10.4,http://192.168.10.4:8000,http://localhost:8000,http://127.0.0.1:8000",
    ).split(",")
    if origin.strip()
]

SSH_BASE = [
    "ssh",
    "-o",
    "BatchMode=yes",
    "-o",
    "ConnectTimeout=8",
    PROXMOX_SSH_TARGET,
]

app = FastAPI(title="CTFd Cyber Range Lab API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=LAB_ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["*"],
)

active_labs: dict[str, dict[str, Any]] = {}


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def client_key(request: Request) -> str:
    user = request.headers.get("x-ctfd-user") or request.headers.get("x-forwarded-user")
    if user:
        return f"user:{user}"

    forwarded_for = request.headers.get("x-forwarded-for", "")
    if forwarded_for:
        return f"ip:{forwarded_for.split(',', maxsplit=1)[0].strip()}"

    if request.client:
        return f"ip:{request.client.host}"

    return "anonymous"


def run_remote(command: str, timeout: int = 30, check: bool = True) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        SSH_BASE + [command],
        capture_output=True,
        check=False,
        text=True,
        timeout=timeout,
    )

    if check and completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip() or "remote command failed"
        raise RuntimeError(detail)

    return completed


def ctid_ip(ctid: int) -> str:
    return f"{LAB_NETWORK_PREFIX}.{ctid - 500}"


def terminal_url(ip_address: str) -> str:
    return f"http://{ip_address}:{LAB_TTYD_PORT}"


def is_lab_expired(lab: dict[str, Any]) -> bool:
    expires_at = lab.get("expires_at")
    return isinstance(expires_at, datetime) and utc_now() >= expires_at


def lab_payload(ctid: int, ip_address: str, status: str = "started") -> dict[str, Any]:
    expires_at = utc_now() + timedelta(seconds=LAB_EXPIRES_SECONDS)
    return {
        "status": status,
        "ctid": ctid,
        "ip_address": ip_address,
        "terminal_url": terminal_url(ip_address),
        "expires_in": "2 hours",
        "expires_at": expires_at,
    }


def public_payload(lab: dict[str, Any]) -> dict[str, Any]:
    return {
        "status": lab["status"],
        "ctid": lab["ctid"],
        "ip_address": lab["ip_address"],
        "terminal_url": lab["terminal_url"],
        "expires_in": lab["expires_in"],
    }


def container_exists(ctid: int) -> bool:
    result = run_remote(f"pct status {ctid}", timeout=12, check=False)
    return result.returncode == 0


def choose_available_ctid() -> int:
    candidates = list(range(CTID_MIN, CTID_MAX + 1))
    random.shuffle(candidates)

    for ctid in candidates:
        if not container_exists(ctid):
            return ctid

    raise HTTPException(status_code=503, detail="No lab CTIDs are currently available.")


def wait_for_ip(ctid: int) -> str:
    deadline = time.time() + LAB_READY_TIMEOUT
    command = "pct exec {ctid} -- ip -4 addr show eth0 | awk '/inet / {{print $2}}' | cut -d/ -f1".format(
        ctid=ctid
    )

    while time.time() < deadline:
        result = run_remote(command, timeout=12, check=False)
        ip_address = result.stdout.strip()

        if ip_address:
            return ip_address

        time.sleep(2)

    raise RuntimeError(f"Lab {ctid} did not receive an IP address in time.")


def wait_for_terminal(ip_address: str) -> None:
    deadline = time.time() + LAB_READY_TIMEOUT
    url = terminal_url(ip_address)

    while time.time() < deadline:
        try:
            with urlopen(url, timeout=3) as response:
                if 200 <= response.status < 500:
                    return
        except URLError:
            pass
        except TimeoutError:
            pass

        time.sleep(2)

    raise RuntimeError(f"ttyd did not become reachable at {url}.")


def spawn_container(ctid: int) -> str:
    run_remote(f"{PROXMOX_SPAWN_SCRIPT} {ctid}", timeout=90)
    ip_address = wait_for_ip(ctid)
    wait_for_terminal(ip_address)
    return ip_address


@app.get("/health")
def health():
    return {
        "status": "ok",
        "proxmox": PROXMOX_SSH_TARGET,
        "ctid_range": [CTID_MIN, CTID_MAX],
    }


@app.get("/spawn")
def spawn_lab(request: Request):
    key = client_key(request)
    existing_lab = active_labs.get(key)

    if existing_lab and not is_lab_expired(existing_lab):
        return public_payload(existing_lab | {"status": "existing"})

    if existing_lab:
        active_labs.pop(key, None)

    ctid = choose_available_ctid()

    try:
        ip_address = spawn_container(ctid)
    except Exception as error:
        raise HTTPException(status_code=502, detail=f"Lab provisioning failed: {error}") from error

    lab = lab_payload(ctid, ip_address)
    active_labs[key] = lab
    return public_payload(lab)


@app.get("/lab")
def current_lab(request: Request):
    key = client_key(request)
    existing_lab = active_labs.get(key)

    if not existing_lab or is_lab_expired(existing_lab):
        raise HTTPException(status_code=404, detail="No active lab for this client.")

    return public_payload(existing_lab)
