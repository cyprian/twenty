#!/bin/bash
set -euo pipefail

APP_DIR=/opt/apps/twenty
RUNTIME_DIR=/opt/twenty-runtime

cd "$APP_DIR"
git fetch origin production
git checkout production
git pull --ff-only origin production

COMMIT_SHA="$(git rev-parse --short=12 HEAD)"
APP_VERSION="0.0.0-eyepic.$COMMIT_SHA"
IMAGE_SHA_TAG="eyepic/twenty:$COMMIT_SHA"
IMAGE_PRODUCTION_TAG="eyepic/twenty:production"

mkdir -p "$RUNTIME_DIR/backups"
cp self-hosting/eyepic/docker-compose.yml "$RUNTIME_DIR/docker-compose.yml"

echo "Building $IMAGE_SHA_TAG from cyprian/twenty..."
docker build \
  --target twenty \
  --build-arg "APP_VERSION=$APP_VERSION" \
  -f packages/twenty-docker/twenty/Dockerfile \
  -t "$IMAGE_SHA_TAG" \
  -t "$IMAGE_PRODUCTION_TAG" \
  .

cd "$RUNTIME_DIR"
if docker compose ps --format json 2>/dev/null | grep -q '"Service":"db"'; then
  echo "Creating pre-deploy database backup..."
  docker compose exec -T db pg_dumpall -U "${PG_DATABASE_USER:-postgres}" >"backups/pre_deploy_${COMMIT_SHA}_$(date +%Y%m%d_%H%M%S).sql" || true
fi

echo "Pulling infrastructure images..."
docker compose pull db redis

echo "Starting Twenty..."
docker compose up -d --remove-orphans

echo "Waiting for healthcheck..."
for i in $(seq 1 120); do
  if curl -fsS http://127.0.0.1:3000/healthz >/dev/null; then
    echo "Twenty is healthy."
    docker compose ps
    exit 0
  fi
  sleep 5
done

echo "Twenty did not become healthy in time."
docker compose ps
docker compose logs --tail=200 server
exit 1
