# syntax=docker/dockerfile:1.7
#
# Multi-stage build for the bilan-carbone Next.js app (monorepo with Yarn workspaces).
# Stages:
#   1. base    — pinned Node + system deps
#   2. deps    — install all workspace deps (incl. publicodes sub-packages via postinstall)
#   3. builder — prebuild publicodes, prisma generate, next build, copy-assets
#   4. runner  — minimal runtime image (Next standalone + prisma CLI + tsx for seed)
#
# Build context: repository ROOT (not deploy/).
# Build command (from repo root):
#   docker build -f deploy/Dockerfile -t bilan-carbone:local .
#

# =============================================================================
# 1. base
# =============================================================================
FROM node:22.16.0-bookworm-slim AS base
ENV CI=true \
    YARN_CACHE_FOLDER=/root/.yarn \
    NEXT_TELEMETRY_DISABLED=1 \
    NODE_OPTIONS=--max-old-space-size=4096
# Placeholder DSN required by prisma.config.ts at INSTALL time. The bilan-carbone
# postinstall hook invokes `prisma generate` which loads the config and reads
# POSTGRES_PRISMA_URL via prisma's `env()` helper — that helper throws if unset.
# Prisma generate doesn't actually connect to the DB; the value just has to be
# a syntactically valid DSN. The real value is injected by Coolify at runtime.
ENV POSTGRES_PRISMA_URL="postgresql://placeholder:placeholder@localhost:5432/placeholder?options=-c%20search_path%3Dpublic%2Cbilan_carbone%2Ccommon"
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssl ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# =============================================================================
# 2. deps — full workspace install
# =============================================================================
# We copy the manifests first so Docker can cache the install layer when only
# source code changes. The `postinstall` hook of bilan-carbone will:
#   - run yarn install in the 3 publicodes-packages
#   - run prisma generate via packages/db-common
# So we need the full prisma schema + the publicodes-packages tree available.
FROM base AS deps

# Workspace root manifests
COPY package.json yarn.lock turbo.json tsconfig.base.json .yarnrc.yaml* ./

# App + packages manifests (only package.json files, for layer caching)
COPY apps/bilan-carbone/package.json ./apps/bilan-carbone/
COPY packages/db-common/package.json ./packages/db-common/
COPY packages/types/package.json ./packages/types/
COPY packages/ui/package.json ./packages/ui/

# Publicodes sub-packages — bilan-carbone's postinstall does `yarn install` in each.
# Copy each sub-package fully (their compile step runs in prebuild, not here).
COPY apps/bilan-carbone/publicodes-packages ./apps/bilan-carbone/publicodes-packages

# Prisma schema needed by `prisma generate` invoked from postinstall
COPY packages/db-common/prisma ./packages/db-common/prisma
COPY packages/db-common/prisma.config.ts ./packages/db-common/

# NODE_ENV=development forced inline because Coolify passes
# NODE_ENV=production as a build-arg, which causes yarn 1.x to skip
# devDependencies regardless of --production=false. We need devDeps
# (typescript, eslint, @types/*) for `next build` to work.
RUN NODE_ENV=development yarn install --frozen-lockfile --production=false --network-timeout 600000

# react-gauge-chart imports `lodash/isEqual` directly. lodash is a transitive
# dep listed in yarn.lock but not declared by any package.json, so Yarn does
# not hoist it to the root node_modules and Turbopack fails to resolve it
# during `next build`. Add it explicitly to the workspace root (won't update
# yarn.lock in our Git, only inside this container layer).
RUN NODE_ENV=development yarn add --ignore-workspace-root-check --network-timeout 600000 lodash@^4.17.23

# =============================================================================
# 3. builder — prebuild + Next build + copy-assets
# =============================================================================
FROM base AS builder

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/bilan-carbone/node_modules ./apps/bilan-carbone/node_modules
COPY --from=deps /app/apps/bilan-carbone/publicodes-packages ./apps/bilan-carbone/publicodes-packages
COPY --from=deps /app/packages ./packages

# Bring in the rest of the source
COPY . .

# .env is required at build time by prisma.config.ts (dotenv/config) and by Next
# during static analysis. We use the dist file with placeholder values — the
# real values are injected at runtime via env vars.
RUN cp apps/bilan-carbone/.env.dist apps/bilan-carbone/.env \
    && cp apps/bilan-carbone/.env.dist packages/db-common/.env

# Compile the 3 publicodes models, generate prisma client, build Next, copy assets.
# The standalone output ends up at apps/bilan-carbone/.next/standalone/
RUN yarn workspace bilan-carbone prebuild \
    && yarn workspace @repo/db-common db:generate \
    && yarn workspace bilan-carbone build

# =============================================================================
# 4. runner — minimal runtime
# =============================================================================
FROM base AS runner
ENV NODE_ENV=production \
    PORT=3000 \
    HOSTNAME=0.0.0.0

# Strategy: ship the full builder workspace tree, not a slim cherry-pick.
# Image is ~1 GB but eliminates whack-a-mole MODULE_NOT_FOUND errors at
# runtime (each transitive dep, symlink, .wasm file, etc. just works).
#
# Order matters:
#   1. Standalone Next.js bundle first — gives server.js, .next/, public/,
#      and a slim package.json tuned for `node server.js`.
#   2. Then OVERWRITE node_modules with the full version. The full set is
#      a superset of what Next traced, so the server still finds everything,
#      and prisma + tsx + their entire transitive dep tree (effect, etc.)
#      are now available for migrations and seed.
#   3. Workspace packages (@repo/db-common etc.) at the right path.
#   4. Prisma schema + seed sources for the entrypoint.
COPY --from=builder /app/apps/bilan-carbone/.next/standalone  ./
COPY --from=builder /app/node_modules                         ./node_modules
COPY --from=builder /app/apps/bilan-carbone/node_modules      ./apps/bilan-carbone/node_modules
COPY --from=builder /app/packages                             ./packages
COPY --from=builder /app/apps/bilan-carbone/prisma            ./apps/bilan-carbone/prisma
COPY --from=builder /app/apps/bilan-carbone/prisma.config.ts  ./apps/bilan-carbone/prisma.config.ts
# tsconfig files needed so tsx can resolve `@/...` path aliases when running the seed
COPY --from=builder /app/apps/bilan-carbone/tsconfig.json     ./apps/bilan-carbone/tsconfig.json
COPY --from=builder /app/tsconfig.base.json                   ./tsconfig.base.json
# Source files referenced by the seed via @/* alias (constants, types, helpers)
COPY --from=builder /app/apps/bilan-carbone/src               ./apps/bilan-carbone/src

# Entrypoint script (migrations + optional seed + start server)
COPY deploy/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["node", "apps/bilan-carbone/server.js"]
