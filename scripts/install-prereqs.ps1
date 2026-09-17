# Instala o toolkit de DevOps usando winget ou Chocolatey.
# Inclui o conjunto completo de utilitários para o dia a dia de DevOps.
$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""
  exit
}

function log($message) { Write-Host "==> $message" }

function install_choco() {
  $chocoDir = "$env:ProgramData\chocolatey"
  $script:choco = "$chocoDir\bin\choco.exe"
  if (Test-Path $script:choco) { return }
  if (Test-Path $chocoDir) {
    throw "Chocolatey está incompleto. Remova '$chocoDir' em um PowerShell como Administrador e execute este script novamente."
  }

  log "Instalando Chocolatey"
  Set-ExecutionPolicy Bypass -Scope Process -Force
  Invoke-Expression ((Invoke-WebRequest https://community.chocolatey.org/install.ps1 -UseBasicParsing).Content)
}

function install($binary, $wingetPackage, $chocoPackage) {
  if (Get-Command $binary -ErrorAction SilentlyContinue) {
    log "$binary já instalado"
    return
  }

  log "Instalando $binary"
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id $wingetPackage -e --accept-source-agreements --accept-package-agreements
  } else {
    & $script:choco install $chocoPackage -y
  }
}

function install_mgc() {
  if (Get-Command mgc -ErrorAction SilentlyContinue) {
    log "mgc já instalado"
    return
  }

  log "Instalando mgc CLI"
  $release = Invoke-RestMethod https://api.github.com/repos/MagaluCloud/mgccli/releases/latest
  $asset = $release.assets | Where-Object { $_.name -match "windows.*amd64" } | Select-Object -First 1
  $installDir = "$env:LocalAppData\mgc-cli"
  $zipPath = "$env:TEMP\mgccli.zip"

  New-Item -ItemType Directory -Force -Path $installDir | Out-Null
  Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath
  Expand-Archive $zipPath -DestinationPath $installDir -Force
  Remove-Item $zipPath

  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($userPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$installDir", "User")
    $env:Path += ";$installDir"
  }
}

function install_gh() {
  if (Get-Command gh -ErrorAction SilentlyContinue) {
    log "gh já instalado"
    return
  }
  log "Instalando gh (GitHub CLI)"
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements
  } else {
    & $script:choco install gh -y
  }
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  install_choco
}

# Shell e processamento de texto
install jq jqlang.jq jq
install yq "mikefarah.yq" yq

# Controle de versão
install git Git.Git git
install "git-lfs" "GitHub.git-lfs" git-lfs

# Containers e orquestração
install docker Docker.DockerDesktop docker-desktop
install docker-compose Docker.DockerCompose docker-compose
install kubectl Kubernetes.kubectl kubernetes-cli
install helm Helm.Helm kubernetes-helm

# Cloud e IaC
install_mgc
install aws Amazon.AWSCLI awscli
install az Microsoft.AzureCLI azure-cli
install gcloud Google.CloudSDK google-cloud-sdk
install terraform Hashicorp.Terraform terraform
install ansible RedHat.Ansible.Engine ansible
install vagrant Hashicorp.Vagrant vagrant

# HTTP e APIs
install curl cURL.cURL curl
install wget GNU.Wget wget
install httpie httpie.httpie httpie

# Rede e diagnóstico
install traceroute "OpenJS.Nodejs" # fallback; traceroute nativo do Windows via tracert
install nmap Insecure.Nmap nmap
install mtr "null" mtr

# Observabilidade
install htop "null" htop

# CI/CD e produtividade
install make GnuWin32.Make make
install_gh
install openssl "ShiningLight.OpenSSL" openssl
install rsync "null" rsync
install vim vim.vim vim
install tmux "null" tmux
install python3 Python.Python.3.12 python

# Segurança
install gpg GnuPG.GnuPG gpg
install vault Hashicorp.Vault vault

Write-Host ""
log "Toolkit de DevOps instalado! Resumo:"
log "  - Nuvem:  mgc, aws, az, gcloud"
log "  - IaC:    terraform, ansible, vagrant"
log "  - K8s:    kubectl, helm, docker"
log "  - Outros: git, gh, jq, yq, curl, httpie, tmux, etc."
Write-Host ""
log "Feche e reabra o terminal, depois autentique nas CLIs que for usar."
log "Ex.:  mgc auth login   |   aws configure   |   az login"
