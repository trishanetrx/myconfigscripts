#!/usr/bin/env bash
set -e

# ==================================================
# CONFIGURATION
# ==================================================
GITHUB_URL="https://github.com/Ventiqo-Technologies"

RUNNER_VERSION="2.331.0"
RUNNER_SHA256="5fcc01bd546ba5c3f1291c2803658ebd3cedb3836489eda3be357d41bfcf28a7"

RUNNER_USER="github-runner"
RUNNER_DIR="/opt/actions-runner"
ARCHIVE="actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

# ==================================================
# FUNCTIONS
# ==================================================

header() {
  echo
  echo "================================================="
  echo " GitHub Actions Runner Manager (Linux)"
  echo "================================================="
}

create_user() {
  if ! id "$RUNNER_USER" &>/dev/null; then
    echo "▶ Creating user: $RUNNER_USER"
    adduser --disabled-password --gecos "" "$RUNNER_USER"
  else
    echo "✔ User $RUNNER_USER already exists"
  fi
}

install_dependencies() {
  echo "▶ Installing system dependencies"
  apt update

  # Core packages
  apt install -y \
    curl \
    ca-certificates \
    tar \
    gnupg \
    lsb-release

  # --------------------
  # Docker
  # --------------------
  if ! command -v docker &>/dev/null; then
    echo "▶ Installing Docker"
    apt install -y docker.io
    systemctl enable docker
    systemctl start docker
  else
    echo "✔ Docker already installed"
  fi

  getent group docker || groupadd docker
  usermod -aG docker "$RUNNER_USER"

  # --------------------
  # Node.js 20 LTS
  # --------------------
  if ! node -v 2>/dev/null | grep -q '^v20'; then
    echo "▶ Installing Node.js 20 LTS"
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
  else
    echo "✔ Node.js 20 already installed"
  fi

  # --------------------
  # yq
  # --------------------
  if ! command -v yq &>/dev/null; then
    echo "▶ Installing yq"
    wget -qO /usr/local/bin/yq \
      https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
  else
    echo "✔ yq already installed"
  fi
}

download_runner() {
  mkdir -p "$RUNNER_DIR"
  cd "$RUNNER_DIR"

  if [ ! -f "$ARCHIVE" ]; then
    echo "▶ Downloading GitHub Actions Runner v${RUNNER_VERSION}"
    curl -L -o "$ARCHIVE" \
      "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${ARCHIVE}"
  else
    echo "✔ Runner archive already exists"
  fi

  echo "▶ Verifying checksum"
  echo "${RUNNER_SHA256}  ${ARCHIVE}" | sha256sum -c -
}

extract_runner() {
  if [ ! -f "$RUNNER_DIR/run.sh" ]; then
    echo "▶ Extracting runner"
    tar xzf "$ARCHIVE"
    rm -f "$ARCHIVE"
  else
    echo "✔ Runner already extracted"
  fi

  chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"
}

configure_runner() {
  DEFAULT_NAME="$(hostname)"
  read -rp "Enter GitHub runner name [$DEFAULT_NAME]: " RUNNER_NAME
  RUNNER_NAME="${RUNNER_NAME:-$DEFAULT_NAME}"

  read -rp "Enter GitHub runner token: " RUNNER_TOKEN

  echo "▶ Configuring runner: $RUNNER_NAME"

  su - "$RUNNER_USER" -c "
    cd $RUNNER_DIR
    ./config.sh --unattended \
      --url $GITHUB_URL \
      --token $RUNNER_TOKEN \
      --name $RUNNER_NAME \
      --labels self-hosted,linux,docker,node20 \
      --replace
  "

  cd "$RUNNER_DIR"
  ./svc.sh install "$RUNNER_USER"
  ./svc.sh start

  echo "✔ Runner installed and running"
}

remove_runner() {
  echo
  read -rp "⚠️  This will REMOVE the GitHub runner. Continue? (y/N): " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || return

  if [ -d "$RUNNER_DIR" ]; then
    echo "▶ Stopping runner service"
    cd "$RUNNER_DIR"
    ./svc.sh stop || true
    ./svc.sh uninstall || true

    if [ -f "$RUNNER_DIR/config.sh" ]; then
      echo "▶ Unregistering runner from GitHub"
      su - "$RUNNER_USER" -c "
        cd $RUNNER_DIR
        ./config.sh remove --unattended
      " || true
    fi

    echo "▶ Removing runner files"
    rm -rf "$RUNNER_DIR"
  else
    echo "ℹ No runner directory found"
  fi

  echo "✔ Runner removed"
}

# ==================================================
# MENU
# ==================================================
header
echo "1) Install / Reinstall GitHub Runner"
echo "2) Remove GitHub Runner"
echo "3) Exit"
echo
read -rp "Select an option [1-3]: " choice

case "$choice" in
  1)
    create_user
    install_dependencies
    download_runner
    extract_runner
    configure_runner
    ;;
  2)
    remove_runner
    ;;
  3)
    echo "Bye 👋"
    exit 0
    ;;
  *)
    echo "Invalid option"
    exit 1
    ;;
esac
