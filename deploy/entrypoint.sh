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
  # The seed file at apps/bilan-carbone/prisma/seed/index.ts has this guard:
  #   if (process.env.NODE_ENV === 'development' || NODE_ENV === 'test')
  #     main(...)
  # In production (NODE_ENV=production), the file loads but main() is never
  # called — silent no-op. We force NODE_ENV=development just for this
  # invocation so main() actually runs and inserts the seed data.
  ( cd /app/apps/bilan-carbone && NODE_ENV=development tsx prisma/seed/index.ts ) || \
    echo "[entrypoint] Seed FAILED — continuing to start server. Re-run seed manually if needed."
  echo "[entrypoint] Seed step done."
fi

# Always reset cwd before exec'ing the server CMD.
cd /app
echo "[entrypoint] Starting server (cwd=$(pwd)): $*"
exec "$@"
