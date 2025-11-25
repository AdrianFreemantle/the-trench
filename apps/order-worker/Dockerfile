FROM node:20-slim

WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./
RUN npm install --omit=dev

COPY src ./src

RUN chown -R node:node /app
USER node

CMD ["node", "src/worker.js"]
