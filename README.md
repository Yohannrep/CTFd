# CTFd Cyber Range Local Dev

This workspace runs a local CTFd stack with the Labs UI added to the core theme.

## Services

- `proxy`: nginx on <http://localhost:8000>
- `ctfd`: full CTFd app, built from the official `ctfd/ctfd` image with Labs patched into the navbar
- `lab-api`: FastAPI-compatible local `/spawn` endpoint
- `terminal`: ttyd browser terminal on <http://localhost:7681>
- `db`: MariaDB
- `cache`: Redis

## Start From VS Code

1. Open this folder in VS Code.
2. Install the recommended Docker extension if prompted.
3. Run the task `CTFd: Docker Compose Up`.
4. Open <http://localhost:8000>.
5. Complete the CTFd setup wizard.
6. Click `Labs` in the navbar.

The local `/spawn` endpoint returns one reusable lab per browser/client and embeds the ttyd terminal automatically.

The Docker build patches the official CTFd navbar instead of replacing it, so normal CTFd navigation remains available.

## Start From Terminal

```powershell
docker compose up --build
```

Open <http://localhost:8000>.

## Stop

```powershell
docker compose down
```

## Reset Local Data

```powershell
docker compose down -v
```

This deletes the local database, uploads, logs, and Redis data.

## Transfer To Proxmox / CTFd VM

Use the VS Code task `Proxmox: Transfer Project`, or run:

```powershell
.\scripts\deploy-to-proxmox.ps1
```

To install the Labs files into the existing CTFd VM at `192.168.10.4`:

```powershell
.\scripts\deploy-to-proxmox.ps1 -InstallLiveTheme
```

See `PROXMOX_DEPLOY.md` for the full transfer and install workflow.

## Where The Labs Code Lives

- `CTFd/themes/core/templates/components/navbar.html`
- `CTFd/themes/core/templates/components/labs_modal.html`
- `CTFd/themes/core/static/js/labs.js`
- `CTFd/themes/core/static/css/labs.css`
- `lab-api/app.py`
- `docker/ctfd/patch_navbar.py`

Later, replace the local `lab-api` behavior with the real Proxmox-backed `/spawn` implementation or point nginx at your existing FastAPI service.
