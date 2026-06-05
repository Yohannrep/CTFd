from fastapi import FastAPI
import subprocess
import random
import time
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/spawn")
def spawn_lab():
    ctid = random.randint(501, 599)

    # 1. Fire off the creation script in the background using an execution list
    spawn_command = ["ssh", "root@192.168.10.2", f"/root/spawn.sh {ctid}"]
    subprocess.Popen(spawn_command, shell=False)

    # 2. Short sleep since static IP assignment happens instantly
    time.sleep(5)

    # 3. Cleanly target the container interface and split out the CIDR mask via awk
    # Executed via array syntax to protect the internal awk routing string from escaping errors
    ip_command = [
        "ssh", 
        "root@192.168.10.2", 
        f"pct exec {ctid} -- ip -4 addr show eth0 | grep inet | awk '{{print $2}}' | cut -d/ -f1"
    ]

    ip = ""

    # 4. Verification loop to ensure the container interface is fully up
    for _ in range(5):
        try:
            ip = subprocess.check_output(
                ip_command,
                shell=False
            ).decode().strip()

            if ip:
                break
        except subprocess.CalledProcessError:
            # If the interface or container isn't active yet, catch the error and retry
            pass

        time.sleep(1)

    # 5. Return the JSON payload back to your CTFd frontend modal
    return {
        "status": "started",
        "ctid": ctid,
        "ip_address": ip,
        "terminal_url": f"http://{ip}:7681",
        "expires_in": "2 hours"
    }
