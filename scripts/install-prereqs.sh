#!/usr/bin/env bash
# Instala o toolkit de DevOps (Debian-Ubuntu/apt, Fedora/dnf ou macOS/Homebrew).
# Inclui o conjunto completo de utilitários para o dia a dia de DevOps.
set -euo pipefail

TMPDIR="${TMPDIR:-/tmp}"

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_apt() { command -v apt-get >/dev/null 2>&1; }
is_dnf() { command -v dnf >/dev/null 2>&1; }
log() { printf '==> %s\n' "$1"; }

apt_install() {
  sudo apt-get update -qq
  sudo apt-get install -y "$@"
}

dnf_install() {
  sudo dnf install -y "$@"
}

brew_install() {
  command -v brew >/dev/null 2>&1 || {
    log "Instalando Homebrew (pode pedir senha)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  }
  brew install "$@"
}

# instala um pacote simples: $1 binário, $2 apt, $3 dnf, $4 brew
install() {
  command -v "$1" >/dev/null 2>&1 && { log "$1 já instalado"; return; }
  log "Instalando $1"
  if is_apt; then apt_install "$2"
  elif is_dnf; then dnf_install "$3"
  elif is_macos; then brew_install "$4"
  else log "Gerenciador de pacotes não reconhecido. Instale $1 manualmente."
  fi
}

# instala um pacote cujo binário pode estar em pacote diferente (ex: dig vem do dnsutils)
install_bin() {
  command -v "$1" >/dev/null 2>&1 && { log "$1 já instalado"; return; }
  log "Instalando $1"
  if is_apt; then apt_install "$2"
  elif is_dnf; then dnf_install "$3"
  elif is_macos; then brew_install "$4"
  else log "Gerenciador de pacotes não reconhecido. Instale $1 manualmente."
  fi
}

# ---------- CLIs de nuvem e ferramentas com instalação especial ----------

install_awscli() {
  command -v aws >/dev/null 2>&1 && { log "aws já instalado"; return; }
  log "Instalando aws"
  if is_macos; then
    brew_install awscli; return
  fi
  command -v unzip >/dev/null 2>&1 || install unzip unzip unzip unzip
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "$TMPDIR/awscliv2.zip"
  unzip -q -o "$TMPDIR/awscliv2.zip" -d "$TMPDIR"
  sudo "$TMPDIR/aws/install" --update
  rm -rf "$TMPDIR/awscliv2.zip" "$TMPDIR/aws"
}

install_mgc() {
  command -v mgc >/dev/null 2>&1 && { log "mgc já instalado"; return; }
  log "Instalando mgc CLI"
  if is_apt; then
    sudo gpg --yes --keyserver keyserver.ubuntu.com --recv-keys 0C59E21A5CB00594 && sudo gpg --export --armor 0C59E21A5CB00594 | sudo gpg --dearmor -o /etc/apt/keyrings/magalu-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/magalu-archive-keyring.gpg] https://packages.magalu.cloud/apt stable main" | sudo tee /etc/apt/sources.list.d/magalu.list
    sudo apt update
    apt_install mgccli
  elif is_macos; then
    brew_install MagaluCloud/mgc/mgccli
  else
    local arch url
    arch=amd64; [ "$(uname -m)" = "aarch64" ] && arch=arm64
    url=$(curl -sSL https://api.github.com/repos/MagaluCloud/mgccli/releases/latest \
      | grep -o "https://[^\"]*linux_${arch}\.tar\.gz")
    curl -sSL "$url" -o "$TMPDIR/mgc.tar.gz"
    tar -xzf "$TMPDIR/mgc.tar.gz" -C "$TMPDIR"
    sudo install -m 755 "$TMPDIR/mgc" /usr/local/bin/mgc
    rm -f "$TMPDIR/mgc.tar.gz" "$TMPDIR/mgc"
  fi
}

install_gh() {
  command -v gh >/dev/null 2>&1 && { log "gh já instalado"; return; }
  log "Instalando gh (GitHub CLI)"
  if is_apt; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    apt_install gh
  elif is_dnf; then
    sudo curl -fsSL https://cli.github.com/packages/rpm/gh-cli.repo -o /etc/yum.repos.d/gh-cli.repo
    sudo dnf install -y gh
  elif is_macos; then
    brew_install gh
  fi
}

install_kubectl() {
  command -v kubectl >/dev/null 2>&1 && { log "kubectl já instalado"; return; }
  log "Instalando kubectl"
  if is_macos; then
    brew_install kubectl; return
  fi
  local version url
  version=$(curl -sSL https://dl.k8s.io/release/stable.txt)
  url="https://dl.k8s.io/release/${version}/bin/linux/$(uname -m)/kubectl"
  curl -sSL "$url" -o "$TMPDIR/kubectl"
  sudo install -m 755 "$TMPDIR/kubectl" /usr/local/bin/kubectl
  rm -f "$TMPDIR/kubectl"
}

install_helm() {
  command -v helm >/dev/null 2>&1 && { log "helm já instalado"; return; }
  log "Instalando helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

install_terraform() {
  command -v terraform >/dev/null 2>&1 && { log "terraform já instalado"; return; }
  log "Instalando terraform"
  if is_macos; then
    brew_install hashicorp/tap/terraform; return
  fi
  if is_apt; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update
    apt_install terraform
  elif is_dnf; then
    sudo curl -fsSL https://rpm.releases.hashicorp.com/fedora/hashicorp.repo -o /etc/yum.repos.d/hashicorp.repo
    sudo dnf install -y terraform
  fi
}

install_ansible() {
  command -v ansible >/dev/null 2>&1 && { log "ansible já instalado"; return; }
  log "Instalando ansible"
  if is_macos; then
    brew_install ansible; return
  fi
  if is_apt; then apt_install ansible
  elif is_dnf; then dnf_install ansible
  fi
}

install_az() {
  command -v az >/dev/null 2>&1 && { log "az já instalado"; return; }
  log "Instalando Azure CLI (az)"
  if is_macos; then
    brew_install azure-cli; return
  fi
  if is_apt; then
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  elif is_dnf; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo dnf install -y https://packages.microsoft.com/config/rhel/9/packages-microsoft-prod.rpm
    sudo dnf install -y azure-cli
  fi
}

install_gcloud() {
  command -v gcloud >/dev/null 2>&1 && { log "gcloud já instalado"; return; }
  log "Instalando Google Cloud CLI (gcloud)"
  if is_macos; then
    brew_install --cask google-cloud-sdk; return
  fi
  curl -sSL https://sdk.cloud.google.com | bash
}

# ---------- Instalações ----------

# Shell e processamento de texto
install jq jq jq jq
install_bin yq yq yq yq
install_bin dig dnsutils bind-utils bind
install_bin host dnsutils bind-utils bind

# Controle de versão
install git git git git
install_bin git-lfs git-lfs git-lfs git-lfs

# Containers e orquestração
install_bin docker docker.io docker docker
install_bin docker-compose docker-compose docker-compose docker-compose
install_kubectl
install_helm

# Cloud e IaC
install_mgc
install_awscli
install_az
install_gcloud
install_terraform
install_ansible
install_bin vagrant vagrant vagrant vagrant

# HTTP e APIs
install curl curl curl curl
install wget wget wget wget
install_bin http httpie httpie httpie

# Rede e diagnóstico
install_bin traceroute traceroute traceroute traceroute
install_bin mtr mtr mtr mtr
install_bin nc netcat-openbsd nmap-ncat netcat
install_bin nmap nmap nmap nmap
install_bin netstat net-tools net-tools net-tools
install_bin ss iproute2 iproute2 iproute2
install_bin ip iproute2 iproute2 iproute2

# Observabilidade
install htop htop htop htop
install_bin iostat sysstat sysstat sysstat
install_bin vmstat procps procps-ng procps
install_bin df coreutils coreutils coreutils
install_bin du coreutils coreutils coreutils

# CI/CD e produtividade
install make make make make
install_gh
install_bin openssl openssl openssl openssl
install_bin ssh openssh-client openssh-clients openssh
install_bin scp openssh-client openssh-clients openssh
install_bin rsync rsync rsync rsync
install vim vim vim vim
install tmux tmux tmux tmux
install_bin python3 python3 python3 python3
install_bin pip3 python3-pip python3-pip python3

# Segurança
install_bin gpg gnupg gnupg gnupg
install_bin vault vault vault hashicorp/tap/vault

echo
log "Toolkit de DevOps instalado! Resumo:"
log "  - Nuvem:  mgc, aws, az, gcloud"
log "  - IaC:    terraform, ansible, vagrant"
log "  - K8s:    kubectl, helm, docker"
log "  - Outros: git, gh, jq, yq, curl, httpie, tmux, etc."
echo
log "Próximo passo: autentique nas CLIs de nuvem que for usar."
log "Ex.:  mgc auth login   |   aws configure   |   az login"
