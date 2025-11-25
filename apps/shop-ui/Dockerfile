# Build Next.js app for production
FROM node:20-slim AS deps
WORKDIR /app
ENV NODE_ENV=development
COPY package*.json ./
RUN npm install

FROM node:20-slim AS builder
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

# Copy only what the runtime server needs
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/next.config.ts ./next.config.ts
COPY --from=builder /app/tsconfig.json ./tsconfig.json

RUN chown -R node:node /app
USER node

EXPOSE 3000
CMD ["npm", "run", "start"]
