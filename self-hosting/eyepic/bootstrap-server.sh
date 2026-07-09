#!/bin/bash
set -euo pipefail

APP_DIR=/opt/apps/twenty
RUNTIME_DIR=/opt/twenty-runtime
REPO_URL=https://github.com/cyprian/twenty.git
DOMAIN=crm.eyepic.io

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    return
  fi

  apt-get update
  apt-get install -y ca-certificates curl gnupg git lsb-release
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  . /etc/os-release
  docker_codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $docker_codename stable" >/etc/apt/sources.list.d/docker.list

  if ! apt-get update; then
    echo "Docker repository for $docker_codename is unavailable; falling back to noble."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" >/etc/apt/sources.list.d/docker.list
    apt-get update
  fi
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_caddy() {
  if command -v caddy >/dev/null 2>&1; then
    return
  fi

  apt-get update
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
  curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt" >/etc/apt/sources.list.d/caddy-stable.list
  apt-get update
  apt-get install -y caddy
}

create_env() {
  mkdir -p "$RUNTIME_DIR"
  if [ -f "$RUNTIME_DIR/.env" ]; then
    return
  fi

  local pg_password
  local encryption_key
  local app_secret

  pg_password="$(openssl rand -hex 24)"
  encryption_key="$(openssl rand -base64 32)"
  app_secret="$(openssl rand -base64 32)"

  cat >"$RUNTIME_DIR/.env" <<EOF
IMAGE_TAG=production
SERVER_URL=https://$DOMAIN
PG_DATABASE_NAME=default
PG_DATABASE_USER=postgres
PG_DATABASE_PASSWORD=$pg_password
PG_DATABASE_HOST=db
PG_DATABASE_PORT=5432
REDIS_URL=redis://redis:6379
ENCRYPTION_KEY=$encryption_key
FALLBACK_ENCRYPTION_KEY=
APP_SECRET=$app_secret
STORAGE_TYPE=local
IS_EMAIL_VERIFICATION_REQUIRED=false
EMAIL_DRIVER=LOGGER
EOF
  chmod 600 "$RUNTIME_DIR/.env"
}

clone_repo() {
  mkdir -p /opt/apps
  if [ -d "$APP_DIR/.git" ]; then
    return
  fi

  git clone "$REPO_URL" "$APP_DIR"
}

install_deploy_script() {
  cp "$APP_DIR/self-hosting/eyepic/deploy-remote.sh" /opt/deploy-twenty.sh
  chmod +x /opt/deploy-twenty.sh
}

configure_caddy() {
  cp "$APP_DIR/self-hosting/eyepic/Caddyfile" /etc/caddy/Caddyfile
  caddy fmt --overwrite /etc/caddy/Caddyfile
  systemctl enable --now caddy
  systemctl reload caddy
}

install_docker
install_caddy
create_env
clone_repo
install_deploy_script
configure_caddy

echo "Bootstrap complete. Run /opt/deploy-twenty.sh to deploy."
