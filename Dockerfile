# Build stage
FROM node:20-slim@sha256:a5e563ed5c60dbf0fd404baaa74e8f40fd45524e58e21f8d35fcbdd690a15056 AS builder

WORKDIR /app

# Copy workspace root files first for better layer caching
COPY package.json package-lock.json* tsconfig.json turbo.json ./
COPY apps/web/package.json apps/web/
COPY services/api/package.json services/api/
COPY packages/ui/package.json packages/ui/
COPY packages/utils/package.json packages/utils/

# Install dependencies using lockfile or fresh install
RUN if test -f package-lock.json; then npm ci --no-audit --no-fund; else npm install --no-audit --no-fund; fi && \
    rm -rf /root/.npm/_cacache

# Copy full source
COPY . .

# Build both web and api
RUN npx turbo build --filter=@elo-tech/api --filter=@elo-tech/web

# Production stage (for api)
FROM node:20-slim@sha256:a5e563ed5c60dbf0fd404baaa74e8f40fd45524e58e21f8d35fcbdd690a15056 AS api

WORKDIR /app

# Copy built API and dependencies
COPY --from=builder /app/services/api/dist ./dist
COPY --from=builder /app/services/api/package.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/services/api/node_modules ./node_modules
COPY --from=builder /app/packages ./packages

EXPOSE 4000

CMD ["node", "dist/main"]
