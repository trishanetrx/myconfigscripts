#!/usr/bin/env bash
set -Eeuo pipefail

#######################################
# n8n production-grade installer
# Modes:
#   1) localhost -> n8n + SQLite, bound to 127.0.0.1 only
#   2) domain    -> n8n + Postgres + Nginx + Let's Encrypt SSL
#
# Notes:
# - Ubuntu only
# - Safe to re-run
# - Preserves existing encryption key and DB password
# - Adds a daily backup job
#######################################

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

APP_DIR="/opt/n8n"
DATA_DIR="${APP_DIR}/data"
POSTGRES_DIR="${APP_DIR}/postgres"
BACKUP_DIR="${APP_DIR}/backups"
COMPOSE_FILE="${APP_DIR}/docker-compose.yml"
ENV_FILE="${APP_DIR}/.env"
CREDENTIALS_FILE="${APP_DIR}/.credentials"
BACKUP_SCRIPT="/usr/local/bin/n8n-backup"
CRON_FILE="/etc/cron.d/n8n-backup"
NGINX_SITE="/etc/nginx/sites-available/n8n"
NGINX_ENABLED="/etc/nginx/sites-enabled/n8n"

PORT="5678"
TZ="Asia/Colombo"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:16-alpine}"
N8N_VERSION="${N8N_VERSION:-1.70.2}"
N8N_IMAGE="docker.n8n.io/n8nio/n8n:${N8N_VERSION}"

log()  { echo -e "\n==> $*"; }
warn() { echo -e "\n[WARN] $*"; }
die()  { echo -e "\n[ERROR] $*" >&2; exit 1; }

cleanup_on_error() {
  local exit_code=$?
  echo
  echo "[ERROR] Script failed on line ${BASH_LINENO[0]} with exit code ${exit_code}"
  echo "Check the output above for the exact failing command."
  exit "${exit_code}"
}
trap cleanup_on_error ERR

require_ubuntu() {
  [[ -r /etc/os-release ]] || die "/etc/os-release not found"
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID}" == "ubuntu" ]] || die "This installer currently supports Ubuntu only"
}

check_hardware() {
  local ram_kb
  ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  if [[ "${ram_kb}" -lt 1800000 ]]; then
    warn "This system has less than 2GB of RAM. n8n might be unstable."
    echo "Press Ctrl+C to abort or wait 5 seconds to continue anyway..."
    sleep 5
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

generate_secret() {
  openssl rand -hex "$1"
}

ensure_dir() {
  local dir="$1"
  mkdir -p "$dir"
}

write_root_only_file() {
  local file="$1"
  chmod 600 "$file"
  chown root:root "$file"
}

get_existing_env_value() {
  local key="$1"
  if [[ -f "${ENV_FILE}" ]]; then
    awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/,""); print; exit}' "${ENV_FILE}" || true
  fi
}

prompt_mode() {
  echo "====================================="
  echo "Select n8n installation mode:"
  echo "1) Localhost (no SSL, dev/testing)"
  echo "2) Domain (Nginx + SSL, production)"
  echo "====================================="
  read -rp "Enter choice (1 or 2): " MODE_CHOICE

  case "${MODE_CHOICE}" in
    1) MODE="localhost" ;;
    2) MODE="domain" ;;
    *) die "Invalid choice" ;;
  esac
}

prompt_domain_details() {
  read -rp "Enter your domain (e.g. n8n.example.com): " DOMAIN
  read -rp "Enter your email for SSL (e.g. admin@example.com): " EMAIL

  [[ -n "${DOMAIN}" ]] || die "Domain is required"
  [[ -n "${EMAIL}" ]] || die "Email is required"

  if ! [[ "${DOMAIN}" =~ ^[A-Za-z0-9.-]+$ ]]; then
    die "Domain format looks invalid"
  fi

  if ! [[ "${EMAIL}" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
    die "Email format looks invalid"
  fi
}

install_base_packages() {
  log "Updating package index"
  apt-get update -y

  log "Installing base packages"
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    ufw \
    openssl \
    cron
}

install_domain_packages() {
  if [[ "${MODE}" == "domain" ]]; then
    log "Installing Nginx and Certbot"
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      nginx \
      certbot \
      python3-certbot-nginx \
      jq
  fi
}

install_docker_if_needed() {
  if command_exists docker && docker compose version >/dev/null 2>&1; then
    log "Docker and Docker Compose already installed"
    return
  fi

  log "Installing Docker Engine and Compose plugin"
  install -m 0755 -d /etc/apt/keyrings

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg

  chmod a+r /etc/apt/keyrings/docker.gpg

  # shellcheck disable=SC1091
  source /etc/os-release
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  systemctl enable docker
  systemctl start docker
}

configure_firewall() {
  log "Configuring firewall"
  ufw allow 22/tcp >/dev/null || true

  if [[ "${MODE}" == "domain" ]]; then
    ufw allow 80/tcp >/dev/null || true
    ufw allow 443/tcp >/dev/null || true
  fi

  ufw --force enable >/dev/null || true
}

prepare_directories() {
  log "Preparing directories"
  ensure_dir "${APP_DIR}"
  ensure_dir "${DATA_DIR}"
  ensure_dir "${BACKUP_DIR}"

  chmod 700 "${APP_DIR}"

  if id -u 1000 >/dev/null 2>&1; then
    chown -R 1000:1000 "${DATA_DIR}"
  fi

  if [[ "${MODE}" == "domain" ]]; then
    ensure_dir "${POSTGRES_DIR}"
    chown -R 999:999 "${POSTGRES_DIR}" || true
  fi
}

load_or_create_env() {
  log "Loading or generating secrets"

  local existing_n8n_key existing_pg_db existing_pg_user existing_pg_pass
  existing_n8n_key="$(get_existing_env_value "N8N_ENCRYPTION_KEY")"
  existing_pg_db="$(get_existing_env_value "POSTGRES_DB")"
  existing_pg_user="$(get_existing_env_value "POSTGRES_USER")"
  existing_pg_pass="$(get_existing_env_value "POSTGRES_PASSWORD")"

  N8N_ENCRYPTION_KEY="${existing_n8n_key:-$(generate_secret 32)}"

  if [[ "${MODE}" == "domain" ]]; then
    POSTGRES_DB="${existing_pg_db:-n8n}"
    POSTGRES_USER="${existing_pg_user:-n8n}"
    POSTGRES_PASSWORD="${existing_pg_pass:-$(generate_secret 24)}"
  fi

  if [[ "${MODE}" == "localhost" ]]; then
    cat > "${ENV_FILE}" <<EOF
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
TZ=${TZ}
EOF
  else
    cat > "${ENV_FILE}" <<EOF
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
TZ=${TZ}
EOF
  fi

  write_root_only_file "${ENV_FILE}"
}

write_compose_file() {
  log "Writing Docker Compose file"

  if [[ "${MODE}" == "localhost" ]]; then
    cat > "${COMPOSE_FILE}" <<EOF
services:
  n8n:
    image: ${N8N_IMAGE}
    container_name: n8n
    restart: unless-stopped
    ports:
      - "127.0.0.1:${PORT}:${PORT}"
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 256M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    environment:
      N8N_HOST: localhost
      N8N_PORT: ${PORT}
      N8N_PROTOCOL: http
      WEBHOOK_URL: http://localhost:${PORT}/
      NODE_ENV: production
      TZ: ${TZ}
      N8N_SECURE_COOKIE: "false"
      N8N_ENCRYPTION_KEY: \${N8N_ENCRYPTION_KEY}
      DB_TYPE: sqlite
    env_file:
      - ${ENV_FILE}
    volumes:
      - ${DATA_DIR}:/home/node/.n8n
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://127.0.0.1:${PORT}/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 40s
EOF
  else
    cat > "${COMPOSE_FILE}" <<EOF
services:
  postgres:
    image: ${POSTGRES_IMAGE}
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: \${POSTGRES_DB}
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      TZ: ${TZ}
    env_file:
      - ${ENV_FILE}
    volumes:
      - ${POSTGRES_DIR}:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 20s
    deploy:
      resources:
        limits:
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  n8n:
    image: ${N8N_IMAGE}
    container_name: n8n
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "127.0.0.1:${PORT}:${PORT}"
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    environment:
      N8N_HOST: ${DOMAIN}
      N8N_PORT: ${PORT}
      N8N_PROTOCOL: https
      WEBHOOK_URL: https://${DOMAIN}/
      NODE_ENV: production
      TZ: ${TZ}
      N8N_SECURE_COOKIE: "true"
      N8N_ENCRYPTION_KEY: \${N8N_ENCRYPTION_KEY}
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: \${POSTGRES_DB}
      DB_POSTGRESDB_USER: \${POSTGRES_USER}
      DB_POSTGRESDB_PASSWORD: \${POSTGRES_PASSWORD}
    env_file:
      - ${ENV_FILE}
    volumes:
      - ${DATA_DIR}:/home/node/.n8n
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://127.0.0.1:${PORT}/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 60s
EOF
  fi

  chmod 644 "${COMPOSE_FILE}"
  chown root:root "${COMPOSE_FILE}"
}

write_nginx_config() {
  [[ "${MODE}" == "domain" ]] || return

  log "Writing Nginx configuration"

  cat > "${NGINX_SITE}" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    client_max_body_size 50m;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
    }
}
EOF

  ln -sfn "${NGINX_SITE}" "${NGINX_ENABLED}"
  rm -f /etc/nginx/sites-enabled/default

  nginx -t
  systemctl enable nginx
  systemctl reload nginx || systemctl restart nginx
}

write_backup_script() {
  log "Writing backup script"

  cat > "${BACKUP_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="/opt/n8n"
DATA_DIR="${APP_DIR}/data"
BACKUP_DIR="${APP_DIR}/backups"
COMPOSE_FILE="${APP_DIR}/docker-compose.yml"
ENV_FILE="${APP_DIR}/.env"
TIMESTAMP="$(date +%F_%H-%M-%S)"

mkdir -p "${BACKUP_DIR}"

if docker ps --format '{{.Names}}' | grep -qx 'n8n-postgres'; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"

  echo "Backing up Postgres database..."
  if ! docker exec n8n-postgres pg_dump \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    --clean \
    --if-exists \
    > "${BACKUP_DIR}/postgres_${TIMESTAMP}.sql"; then
    echo "Postgres backup failed!" >&2
    rm -f "${BACKUP_DIR}/postgres_${TIMESTAMP}.sql"
  else
    echo "Postgres backup completed successfully."
  fi

  tar -czf "${BACKUP_DIR}/n8n_data_${TIMESTAMP}.tar.gz" -C "${DATA_DIR}" .
else
  echo "Backing up n8n data (SQLite mode)..."
  tar -czf "${BACKUP_DIR}/n8n_data_${TIMESTAMP}.tar.gz" -C "${DATA_DIR}" .
fi

echo "Cleaning up backups older than 14 days..."
find "${BACKUP_DIR}" -type f -mtime +14 -delete
echo "Backup process finished."
EOF

  chmod 700 "${BACKUP_SCRIPT}"
  chown root:root "${BACKUP_SCRIPT}"
}

write_backup_cron() {
  log "Configuring daily backup cron"

  cat > "${CRON_FILE}" <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
15 2 * * * root ${BACKUP_SCRIPT} >/var/log/n8n-backup.log 2>&1
EOF

  chmod 644 "${CRON_FILE}"
  chown root:root "${CRON_FILE}"
  systemctl enable cron
  systemctl restart cron
}

start_stack() {
  log "Starting n8n stack"
  docker compose -f "${COMPOSE_FILE}" pull
  docker compose -f "${COMPOSE_FILE}" up -d
}

wait_for_n8n() {
  log "Waiting for n8n health endpoint"

  local i
  for i in {1..30}; do
    if curl -fsS "http://127.0.0.1:${PORT}/healthz" >/dev/null 2>&1; then
      echo "n8n is responding on local health endpoint"
      return 0
    fi
    sleep 5
  done

  warn "n8n health endpoint did not become ready in time"
  docker compose -f "${COMPOSE_FILE}" ps || true
  docker compose -f "${COMPOSE_FILE}" logs --tail=100 || true
  die "n8n failed to become healthy"
}

run_certbot() {
  [[ "${MODE}" == "domain" ]] || return

  log "Running Let's Encrypt dry-run"
  certbot --nginx \
    --non-interactive \
    --agree-tos \
    -m "${EMAIL}" \
    -d "${DOMAIN}" \
    --dry-run

  log "Dry-run succeeded, requesting real certificate"
  certbot --nginx \
    --non-interactive \
    --agree-tos \
    --redirect \
    -m "${EMAIL}" \
    -d "${DOMAIN}"

  nginx -t
  systemctl reload nginx
}

write_credentials_file() {
  log "Writing credentials summary"

  cat > "${CREDENTIALS_FILE}" <<EOF
n8n credentials
===============

Mode: ${MODE}
URL: $([[ "${MODE}" == "domain" ]] && echo "https://${DOMAIN}" || echo "http://localhost:${PORT}")
Login: Create the owner account on the first n8n setup screen.

Important files
===============
Docker Compose: ${COMPOSE_FILE}
Environment: ${ENV_FILE}
Data: ${DATA_DIR}
Backups: ${BACKUP_DIR}
Backup script: ${BACKUP_SCRIPT}

Operations
==========
Start:   docker compose -f ${COMPOSE_FILE} up -d
Stop:    docker compose -f ${COMPOSE_FILE} down
Logs:    docker compose -f ${COMPOSE_FILE} logs -f
Backup:  ${BACKUP_SCRIPT}
EOF

  write_root_only_file "${CREDENTIALS_FILE}"
}

show_summary() {
  echo
  echo "====================================="
  echo "n8n installation completed"
  echo "====================================="
  if [[ "${MODE}" == "domain" ]]; then
    echo "Open: https://${DOMAIN}"
  else
    echo "Open locally on the server: http://localhost:${PORT}"
    echo "Or tunnel/port-forward from your own machine if needed."
  fi
  echo
  echo "Credentials summary saved to: ${CREDENTIALS_FILE}"
  echo "Backups directory: ${BACKUP_DIR}"
  echo
  echo "Useful commands:"
  echo "docker compose -f ${COMPOSE_FILE} ps"
  echo "docker compose -f ${COMPOSE_FILE} logs -f"
}

main() {
  require_ubuntu
  check_hardware
  prompt_mode

  if [[ "${MODE}" == "domain" ]]; then
    prompt_domain_details
  fi

  install_base_packages
  install_domain_packages
  install_docker_if_needed
  configure_firewall
  prepare_directories
  load_or_create_env
  write_compose_file
  write_backup_script
  write_backup_cron

  if [[ "${MODE}" == "domain" ]]; then
    write_nginx_config
  fi

  start_stack
  wait_for_n8n

  if [[ "${MODE}" == "domain" ]]; then
    run_certbot
  fi

  write_credentials_file
  show_summary
}

main "$@"
