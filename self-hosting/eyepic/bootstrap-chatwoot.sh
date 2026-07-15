#!/bin/bash
set -euo pipefail

APP_DIR=/opt/apps/twenty
RUNTIME_DIR=/opt/chatwoot-runtime
DOMAIN=support.eyepic.io

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  echo "Docker Engine and Docker Compose v2 are required. Run the Twenty bootstrap first."
  exit 1
fi

if ! command -v caddy >/dev/null 2>&1; then
  echo "Caddy is required to provide HTTPS. Run the Twenty bootstrap first."
  exit 1
fi

if [ ! -f "$RUNTIME_DIR/.env" ]; then
  install -d -m 700 "$RUNTIME_DIR/backups"
  secret_key_base=$(openssl rand -hex 64)
  postgres_password=$(openssl rand -hex 32)
  redis_password=$(openssl rand -hex 32)
  cat >"$RUNTIME_DIR/.env" <<EOF
CHATWOOT_VERSION=v4.14.0
FRONTEND_URL=https://$DOMAIN
FORCE_SSL=true
ENABLE_ACCOUNT_SIGNUP=false
SECRET_KEY_BASE=$secret_key_base
POSTGRES_HOST=postgres
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=$postgres_password
POSTGRES_DATABASE=chatwoot
REDIS_PASSWORD=$redis_password
REDIS_URL=redis://:$redis_password@redis:6379
RAILS_ENV=production
RAILS_MAX_THREADS=5
ACTIVE_STORAGE_SERVICE=local
RAILS_LOG_TO_STDOUT=true
LOG_LEVEL=info
EOF
  chmod 600 "$RUNTIME_DIR/.env"
fi

if ! grep -q '^CHATWOOT_BUILD_CONTEXT=' "$RUNTIME_DIR/.env"; then
  cat >>"$RUNTIME_DIR/.env" <<EOF
CHATWOOT_BUILD_CONTEXT=$APP_DIR
FIREBASE_PROFILE_ENABLED=false
FIREBASE_PROFILE_GATEWAY_URL=http://firebase-profile:8080
FIREBASE_PROFILE_GATEWAY_TOKEN=$(openssl rand -hex 32)
FIREBASE_PROFILE_CREDENTIALS_FILE=$RUNTIME_DIR/firebase-service-account.json
EOF
  chmod 600 "$RUNTIME_DIR/.env"
fi

# Older deployments used a separate /opt/apps/chatwoot checkout. The overlay
# now lives in this repository, so always build from the current app directory.
sed -i "s|^CHATWOOT_BUILD_CONTEXT=.*|CHATWOOT_BUILD_CONTEXT=$APP_DIR|" "$RUNTIME_DIR/.env"

# Integration hook access tokens (including the per-inbox Eye.photo admin key)
# use Active Record Encryption when all three values are configured. Add them
# independently so existing Chatwoot deployments are upgraded safely as well.
if ! grep -q '^ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=' "$RUNTIME_DIR/.env"; then
  cat >>"$RUNTIME_DIR/.env" <<EOF
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$(openssl rand -base64 36 | tr -dc 'A-Za-z0-9' | head -c 32)
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -base64 36 | tr -dc 'A-Za-z0-9' | head -c 32)
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -base64 36 | tr -dc 'A-Za-z0-9' | head -c 32)
EOF
  chmod 600 "$RUNTIME_DIR/.env"
fi

cp "$APP_DIR/self-hosting/eyepic/chatwoot-compose.yml" "$RUNTIME_DIR/docker-compose.yml"
cp "$APP_DIR/self-hosting/eyepic/Caddyfile" /etc/caddy/Caddyfile
caddy fmt --overwrite /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy

cd "$RUNTIME_DIR"
docker compose pull postgres redis
docker compose build rails sidekiq
docker compose run --rm rails bundle exec rails db:chatwoot_prepare
docker compose run --rm rails bundle exec rails runner "InstallationConfig.where(name: 'INSTALLATION_NAME').update_all(value: 'Eyepic Support'); InstallationConfig.where(name: %w[LOGO LOGO_DARK LOGO_THUMBNAIL]).update_all(value: '/favicon-512x512.png'); GlobalConfig.clear_cache"
if grep -q '^FIREBASE_PROFILE_ENABLED=true$' "$RUNTIME_DIR/.env"; then
  docker compose --profile firebase-profile up -d --build --remove-orphans
else
  docker compose up -d --build --remove-orphans
fi

for _ in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:3001/api >/dev/null; then
    docker compose ps
    exit 0
  fi
  sleep 5
done

docker compose ps
docker compose logs --tail=200 rails sidekiq
echo "Chatwoot did not become healthy in time."
exit 1
