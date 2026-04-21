#!/usr/bin/env bash
set -euo pipefail

DOMAIN="n8n.zanzo.casino"
LETSENCRYPT_EMAIL="admin@zanzo.casino"
APP_DIR="/opt/n8n"
DATA_DIR="${APP_DIR}/data"
COMPOSE_FILE="${APP_DIR}/docker-compose.yml"
NGINX_SITE="/etc/nginx/sites-available/n8n"
N8N_INTERNAL_PORT="5678"
TIMEZONE="Asia/Colombo"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
  echo "This script supports Debian/Ubuntu with apt"
  exit 1
fi

echo "==> Updating system"
apt update
apt upgrade -y

echo "==> Installing packages"
apt install -y ca-certificates curl gnupg lsb-release ufw nginx certbot python3-certbot-nginx

echo "==> Installing Docker repo"
install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

. /etc/os-release
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  ${VERSION_CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

echo "==> Installing Docker"
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

echo "==> Creating directories"
mkdir -p "${APP_DIR}"
mkdir -p "${DATA_DIR}"

echo "==> Writing docker-compose.yml"
cat > "${COMPOSE_FILE}" <<EOF
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    container_name: n8n
    restart: always
    ports:
      - "127.0.0.1:${N8N_INTERNAL_PORT}:${N8N_INTERNAL_PORT}"
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=${N8N_INTERNAL_PORT}
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${DOMAIN}/
      - N8N_PROXY_HOPS=1
      - TZ=${TIMEZONE}
    volumes:
      - ${DATA_DIR}:/home/node/.n8n
EOF

echo "==> Fixing permissions"
chown -R 1000:1000 "${DATA_DIR}"
chmod -R 755 "${DATA_DIR}"

echo "==> Removing old n8n container if present"
docker rm -f n8n >/dev/null 2>&1 || true

echo "==> Starting n8n"
docker compose -f "${COMPOSE_FILE}" up -d

echo "==> Writing Nginx site"
cat > "${NGINX_SITE}" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    client_max_body_size 50m;

    location / {
        proxy_pass http://127.0.0.1:${N8N_INTERNAL_PORT};
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
        proxy_connect_timeout 60;
        proxy_buffering off;
    }
}
EOF

ln -sf "${NGINX_SITE}" /etc/nginx/sites-enabled/n8n
rm -f /etc/nginx/sites-enabled/default

echo "==> Testing Nginx config"
nginx -t
systemctl enable nginx
systemctl reload nginx

echo "==> Configuring firewall"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "==> Running Certbot STAGING test"
certbot --nginx \
  --non-interactive \
  --agree-tos \
  --test-cert \
  -m "${LETSENCRYPT_EMAIL}" \
  -d "${DOMAIN}"

echo "==> Staging test passed"

echo "==> Requesting REAL certificate"
certbot --nginx \
  --non-interactive \
  --agree-tos \
  -m "${LETSENCRYPT_EMAIL}" \
  -d "${DOMAIN}" \
  --redirect

echo "==> Reloading services"
systemctl reload nginx
docker compose -f "${COMPOSE_FILE}" restart

echo
echo "=========================================="
echo "n8n install complete"
echo "URL: https://${DOMAIN}"
echo "App dir: ${APP_DIR}"
echo "Compose file: ${COMPOSE_FILE}"
echo
echo "Useful commands:"
echo "  docker compose -f ${COMPOSE_FILE} ps"
echo "  docker logs -f n8n"
echo "  nginx -t && systemctl reload nginx"
echo "=========================================="
