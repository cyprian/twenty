#!/bin/bash
set -euo pipefail

RUNTIME_DIR=/opt/chatwoot-runtime
BACKUP_DIR="$RUNTIME_DIR/backups"

install -d -m 700 "$BACKUP_DIR"
cd "$RUNTIME_DIR"
set -a
. ./.env
set +a

umask 077
docker compose exec -T postgres pg_dump -U "$POSTGRES_USERNAME" -d chatwoot | gzip -9 >"$BACKUP_DIR/chatwoot_$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
find "$BACKUP_DIR" -type f -name 'chatwoot_*.sql.gz' -mtime +30 -delete
