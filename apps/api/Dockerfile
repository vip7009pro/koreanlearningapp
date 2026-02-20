FROM node:20-alpine AS builder
WORKDIR /app
COPY apps/api/package.json apps/api/yarn.lock* ./
RUN yarn install --frozen-lockfile || yarn install
COPY apps/api/ .
RUN npx prisma generate
RUN yarn build

FROM node:20-alpine AS runner
WORKDIR /app
RUN apk add --no-cache openssl
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/prisma ./prisma

EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy; npx prisma db seed || true; node dist/main"]
