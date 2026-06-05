# Proxmox / CTFd VM Transfer

The project context has two important hosts:

- Proxmox host: `192.168.10.2`
- CTFd VM: `192.168.10.4`

In most cases, transfer this project to the CTFd VM, because that is where CTFd and the FastAPI `/spawn` service live. The Proxmox host should usually stay focused on LXC orchestration.

## Transfer From Windows / VS Code

From the project root:

```powershell
.\scripts\deploy-to-proxmox.ps1
```

Defaults:

- Remote host: `192.168.10.4`
- Remote user: `cce`
- Remote path: `/home/cce/cyber-range-ctfd`

Override them when needed:

```powershell
.\scripts\deploy-to-proxmox.ps1 -RemoteHost 192.168.10.4 -RemoteUser cce -RemotePath /home/cce/cyber-range-ctfd
```

## Install Into Existing CTFd On The VM

This copies the Labs modal, JS, and CSS into `/home/cce/CTFd`, patches the existing CTFd navbar, and creates a timestamped backup of the original navbar.

```powershell
.\scripts\deploy-to-proxmox.ps1 -InstallLiveTheme
```

Then SSH to the VM and restart CTFd using the method your server already uses.

Examples:

```bash
sudo systemctl restart ctfd
```

or:

```bash
cd /home/cce/CTFd
docker compose restart ctfd
```

## Run The Docker Stack On The VM

If you want the self-contained local Docker version to run on the VM:

```powershell
.\scripts\deploy-to-proxmox.ps1 -StartDockerStack
```

Then open:

```text
http://192.168.10.4:8000
```

## Transfer To The Proxmox Host Instead

Only do this if you intentionally want the files on the Proxmox host:

```powershell
.\scripts\deploy-to-proxmox.ps1 -RemoteHost 192.168.10.2 -RemoteUser root -RemotePath /root/cyber-range-ctfd
```

That transfers the project, but it does not install the Labs UI into CTFd because CTFd is expected to live on the CTFd VM.

## What Gets Transferred

- Labs theme files
- Docker Compose local stack
- local FastAPI mock `/spawn`
- nginx proxy config
- VS Code tasks
- install scripts

The script does not transfer `.git`, databases, CTFd uploads, or generated Docker volumes.
