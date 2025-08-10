#!/usr/bin/env bash
set -euo pipefail
 
# ---------------------------------------
# Debian/Ubuntu Dev Tool Bootstrap Script
# Installs: git, kubectl, oh-my-zsh, helm, docker, nvm+node (LTS), python3
# Requires: sudo/root
# ---------------------------------------
 
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi
 
export DEBIAN_FRONTEND=noninteractive
 
log() { printf "\n\033[1;32m==> %s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m[!] %s\033[0m\n" "$*"; }
err() { printf "\n\033[1;31m[✗] %s\033[0m\n" "$*"; }
 
ARCH="$(dpkg --print-architecture)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
: "${USER_HOME:=$HOME}"
 
run_as_user() {
  su - "$USER_NAME" -c "$*"
}
 
. /etc/os-release
DOCKER_REPO_ID="$ID"
DOCKER_REPO_CODENAME="$VERSION_CODENAME"
if [[ -z "${DOCKER_REPO_CODENAME:-}" && -n "${UBUNTU_CODENAME:-}" ]]; then
  DOCKER_REPO_ID="ubuntu"
  DOCKER_REPO_CODENAME="$UBUNTU_CODENAME"
fi
 
log "Updating apt and installing base packages (Git included)"
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg lsb-release git zsh build-essential \
  apt-transport-https software-properties-common
 
mkdir -p /etc/apt/keyrings
chmod 0755 /etc/apt/keyrings
 
install_python() {
  if command -v python3 >/dev/null 2>&1; then
    log "Python3 already installed: $(python3 --version)"
  else
    log "Installing Python 3"
  fi
  apt-get install -y python3 python3-pip python3-venv python3-dev
}
 
install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed: $(docker --version || true)"
    return
  fi
 
  log "Setting up Docker APT repository"
  curl -fsSL "https://download.docker.com/linux/${DOCKER_REPO_ID}/gpg" \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
 
  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DOCKER_REPO_ID} ${DOCKER_REPO_CODENAME} stable" \
> /etc/apt/sources.list.d/docker.list
 
  apt-get update -y
  log "Installing Docker Engine components"
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
 
  if ! getent group docker >/dev/null; then
    groupadd docker
  fi
  usermod -aG docker "$USER_NAME"
}
 
install_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then
    log "kubectl already installed: $(kubectl version --client --short 2>/dev/null || true)"
    return
  fi
 
  log "Installing kubectl (latest stable)"
  case "$ARCH" in
    amd64|x86_64) KARCH="amd64" ;;
    arm64|aarch64) KARCH="arm64" ;;
    armhf|arm) KARCH="arm" ;;
    *) err "Unsupported architecture for kubectl: $ARCH"; return 1 ;;
  esac
 
  TMP="/usr/local/bin/kubectl.tmp"
  STABLE="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
  curl -L --fail "https://dl.k8s.io/release/${STABLE}/bin/linux/${KARCH}/kubectl" -o "$TMP"
  install -m 0755 "$TMP" /usr/local/bin/kubectl
  rm -f "$TMP"
}
 
install_helm() {
  if command -v helm >/dev/null 2>&1; then
    log "Helm already installed: $(helm version --short 2>/dev/null || true)"
    return
  fi
  log "Installing Helm 3"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}
 
install_nvm_node() {
  if [[ -d "${USER_HOME}/.nvm" ]]; then
    log "nvm already present for ${USER_NAME}"
  else
    log "Installing nvm for ${USER_NAME}"
    run_as_user "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
  fi
 
  for SHELL_RC in "${USER_HOME}/.bashrc" "${USER_HOME}/.zshrc"; do
    if [[ -f "$SHELL_RC" ]] && ! grep -q 'NVM_DIR' "$SHELL_RC"; then
      echo 'export NVM_DIR="$HOME/.nvm"' >> "$SHELL_RC"
      echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "$SHELL_RC"
      echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> "$SHELL_RC"
    fi
  done
 
  log "Installing latest LTS Node via nvm for ${USER_NAME}"
  run_as_user "bash -lc 'export NVM_DIR=\$HOME/.nvm; [ -s \$NVM_DIR/nvm.sh ] && . \$NVM_DIR/nvm.sh; nvm install --lts; nvm alias default lts/*; node -v; npm -v'"
}
 
install_oh_my_zsh() {
  if [[ -d "${USER_HOME}/.oh-my-zsh" ]]; then
    log "Oh My Zsh already installed for ${USER_NAME}"
  else
    log "Installing Oh My Zsh for ${USER_NAME} (non-interactive)"
    run_as_user "RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
      \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
  fi
 
  if [[ "$(getent passwd "$USER_NAME" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
    if command -v zsh >/dev/null 2>&1; then
      chsh -s "$(command -v zsh)" "$USER_NAME" || warn "Could not change default shell for ${USER_NAME}"
    fi
  fi
}
 
install_python
install_docker
install_kubectl
install_helm
install_nvm_node
install_oh_my_zsh
 
echo
log "Installation complete!"
echo "Git:             $(git --version 2>/dev/null || echo 'not found')"
echo "User:            $USER_NAME"
echo "Docker:          $(command -v docker >/dev/null 2>&1 && docker --version || echo 'not found')"
echo "kubectl:         $(command -v kubectl >/dev/null 2>&1 && kubectl version --client --short 2>/dev/null || echo 'not found')"
echo "Helm:            $(command -v helm >/dev/null 2>&1 && helm version --short 2>/dev/null || echo 'not found')"
echo "Python:          $(python3 --version 2>/dev/null || echo 'not found')"
echo "Pip:             $(python3 -m pip --version 2>/dev/null || echo 'not found')"
run_as_user "bash -lc 'export NVM_DIR=\$HOME/.nvm; [ -s \$NVM_DIR/nvm.sh ] && . \$NVM_DIR/nvm.sh; echo -n \"Node:            \"; node -v 2>/dev/null || echo not found; echo -n \"npm:             \"; npm -v 2>/dev/null || echo not found'"
 
warn "Note: You may need to log out and back in (or run 'newgrp docker') to use Docker without sudo."
