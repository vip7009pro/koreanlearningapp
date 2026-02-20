FROM node:20-alpine AS builder
WORKDIR /app
COPY apps/admin-web/package.json ./
RUN yarn install --frozen-lockfile || yarn install
COPY apps/admin-web/ .
RUN yarn build

FROM nginx:alpine AS runner
COPY --from=builder /app/dist /usr/share/nginx/html
COPY apps/admin-web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
