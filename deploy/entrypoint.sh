#!/bin/sh
# entrypoint.sh — run migrations (and optionally seed) before starting the server.
#
# Behaviour controlled by env vars:
#   RUN_MIGRATIONS=true   → applies pending migrations on startup (recommended)
#   RUN_SEED=true         → runs the seed (set this only on first deploy, then unset)
#
# All other arguments to the container are exec'd as the main process (the CMD).

set -e

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  echo "[entrypoint] Running prisma migrate deploy..."
  prisma migrate deploy --config ./packages/db-common/prisma.config.ts
  echo "[entrypoint] Migrations applied."
fi

if [ "${RUN_SEED:-false}" = "true" ]; then
  echo "[entrypoint] Running seed..."
  cd ./apps/bilan-carbone && tsx prisma/seed/index.ts && cd /app
  echo "[entrypoint] Seed complete."
fi

echo "[entrypoint] Starting server: $*"
exec "$@"
