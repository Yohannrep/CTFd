param(
  [string]$RemoteHost = "192.168.10.4",
  [string]$RemoteUser = "cce",
  [string]$RemotePath = "/home/cce/cyber-range-ctfd",
  [switch]$InstallLiveTheme,
  [switch]$StartDockerStack
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$DeployDir = Join-Path $Root ".deploy"
$PackageDir = Join-Path $DeployDir "cyber-range-ctfd"
$Archive = Join-Path $DeployDir "cyber-range-ctfd.tar.gz"
$Remote = "${RemoteUser}@${RemoteHost}"

Write-Host "Preparing deployment package from $Root"

if (Test-Path $PackageDir) {
  Remove-Item -LiteralPath $PackageDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null

$Items = @(
  "CTFd",
  "docker",
  "lab-api",
  "scripts",
  ".vscode",
  ".gitignore",
  "docker-compose.yml",
  "README.md",
  "PROXMOX_DEPLOY.md"
)

foreach ($Item in $Items) {
  $Source = Join-Path $Root $Item
  if (Test-Path $Source) {
    Copy-Item -LiteralPath $Source -Destination $PackageDir -Recurse -Force
  }
}

if (Test-Path $Archive) {
  Remove-Item -LiteralPath $Archive -Force
}

Push-Location $DeployDir
try {
  tar -czf "cyber-range-ctfd.tar.gz" "cyber-range-ctfd"
}
finally {
  Pop-Location
}

Write-Host "Creating remote directory $RemotePath on $Remote"
ssh $Remote "mkdir -p '$RemotePath'"

Write-Host "Copying package to $Remote"
scp $Archive "${Remote}:${RemotePath}/cyber-range-ctfd.tar.gz"

Write-Host "Extracting package on remote"
ssh $Remote "cd '$RemotePath' && tar -xzf cyber-range-ctfd.tar.gz --strip-components=1"

if ($InstallLiveTheme) {
  Write-Host "Installing Labs files into the existing CTFd tree on remote"
  ssh $Remote "cd '$RemotePath' && bash scripts/install-on-ctfd-vm.sh --install-live-theme"
}

if ($StartDockerStack) {
  Write-Host "Starting Docker Compose stack on remote"
  ssh $Remote "cd '$RemotePath' && docker compose up -d --build"
}

Write-Host ""
Write-Host "Transfer complete."
Write-Host "Remote project: ${Remote}:${RemotePath}"
Write-Host "CTFd URL when running: http://${RemoteHost}:8000"
