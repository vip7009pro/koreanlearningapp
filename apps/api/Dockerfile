FROM node:20-alpine AS builder
WORKDIR /app
RUN corepack enable
RUN apk add --no-cache openssl
COPY . .
RUN yarn install --frozen-lockfile || yarn install
WORKDIR /app/apps/api
RUN yarn prisma:generate
RUN yarn build

FROM node:20-alpine AS runner
WORKDIR /app/apps/api
RUN apk add --no-cache openssl
ENV PATH="/app/node_modules/.bin:${PATH}"
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/apps/api/package.json ./package.json
COPY --from=builder /app/apps/api/prisma ./prisma
COPY --from=builder /app/apps/api/dist ./dist
COPY docker/.env ./.env

EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy; npx prisma db seed || true; node dist/src/main"]
