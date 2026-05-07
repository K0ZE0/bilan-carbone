#!/bin/sh
# entrypoint.sh — run migrations (and optionally seed) before starting the server.
#
# Behaviour controlled by env vars:
#   RUN_MIGRATIONS=true   → applies pending migrations on startup (recommended)
#   RUN_SEED=true         → runs the seed (set this only on first deploy, then unset)
#
# All other arguments to the container are exec'd as the main process (the CMD).

set -e

# Use local node_modules/.bin (not globals) — required because the prisma
# config files import packages from the workspace's node_modules tree.
export PATH="/app/node_modules/.bin:$PATH"

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  echo "[entrypoint] Running prisma migrate deploy..."
  prisma migrate deploy --config ./packages/db-common/prisma.config.ts
  echo "[entrypoint] Migrations applied."
fi

if [ "${RUN_SEED:-false}" = "true" ]; then
  echo "[entrypoint] Running seed..."
  # Run seed in subshell so its `cd` doesn't leak to the rest of the script.
  # Use `|| true` so a failed seed doesn't prevent the server from starting —
  # the seed can be re-run manually via the Coolify terminal afterwards.
  ( cd /app/apps/bilan-carbone && tsx prisma/seed/index.ts ) || \
    echo "[entrypoint] Seed FAILED — continuing to start server. Re-run seed manually if needed."
  echo "[entrypoint] Seed step done."
fi

# Always reset cwd before exec'ing the server CMD.
cd /app
echo "[entrypoint] Starting server (cwd=$(pwd)): $*"
exec "$@"
