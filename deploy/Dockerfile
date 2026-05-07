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

RUN yarn install --frozen-lockfile --network-timeout 600000

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

# We need:
#   - Next standalone server
#   - Prisma CLI (for `migrate deploy` at startup)
#   - tsx (for `prisma db seed` which runs `tsx prisma/seed/index.ts`)
#   - Prisma schema + generated client + seed source
RUN yarn global add prisma@7.7.0 tsx@4.21.0 \
    && yarn cache clean

# Standalone output (server.js + traced node_modules)
COPY --from=builder /app/apps/bilan-carbone/.next/standalone ./

# .next/static and public are copied into the standalone tree by copy-assets.js
# during build. We don't re-copy them here — they're already in place under
# ./apps/bilan-carbone/.next/static and ./apps/bilan-carbone/public

# Files needed for migrations + seed at runtime
COPY --from=builder /app/packages/db-common/prisma           ./packages/db-common/prisma
COPY --from=builder /app/packages/db-common/prisma.config.ts ./packages/db-common/prisma.config.ts
COPY --from=builder /app/packages/db-common/package.json     ./packages/db-common/package.json

# Seed needs the bilan-carbone prisma folder + its prisma.config.ts + package.json
COPY --from=builder /app/apps/bilan-carbone/prisma            ./apps/bilan-carbone/prisma
COPY --from=builder /app/apps/bilan-carbone/prisma.config.ts  ./apps/bilan-carbone/prisma.config.ts

# Entrypoint script (migrations + optional seed + start server)
COPY deploy/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["node", "apps/bilan-carbone/server.js"]
