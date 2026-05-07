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

# Tools needed at runtime by entrypoint.sh:
#   - prisma CLI: `prisma migrate deploy`
#   - dotenv: imported by prisma.config.ts (`import 'dotenv/config'`)
#   - tsx: runs the seed (`tsx prisma/seed/index.ts`)
# We install them in /app/node_modules (not globally) because prisma.config.ts
# does `import { defineConfig, env } from 'prisma/config'` and Node module
# resolution from /app/packages/db-common/prisma.config.ts walks up the tree
# to /app/node_modules. Globals (~/.yarn/global) are not on that path.
COPY --from=builder /app/node_modules/dotenv             ./node_modules/dotenv
COPY --from=builder /app/node_modules/prisma             ./node_modules/prisma
COPY --from=builder /app/node_modules/@prisma            ./node_modules/@prisma
COPY --from=builder /app/node_modules/tsx                ./node_modules/tsx
# tsx peer deps (esbuild + helpers it shells out to)
COPY --from=builder /app/node_modules/esbuild            ./node_modules/esbuild
COPY --from=builder /app/node_modules/get-tsconfig       ./node_modules/get-tsconfig
COPY --from=builder /app/node_modules/resolve-pkg-maps   ./node_modules/resolve-pkg-maps
# Recreate the .bin symlinks. We can't COPY them — Docker dereferences
# symlinks during COPY, turning the prisma/tsx shim scripts into real files
# at /app/node_modules/.bin/, which breaks their `__dirname`-relative wasm
# and binary lookups (prisma_schema_build_bg.wasm not found).
RUN mkdir -p /app/node_modules/.bin \
    && ln -sf ../prisma/build/index.js /app/node_modules/.bin/prisma \
    && ln -sf ../tsx/dist/cli.mjs /app/node_modules/.bin/tsx \
    && chmod +x /app/node_modules/prisma/build/index.js \
    && chmod +x /app/node_modules/tsx/dist/cli.mjs

# Entrypoint script (migrations + optional seed + start server)
COPY deploy/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["node", "apps/bilan-carbone/server.js"]
