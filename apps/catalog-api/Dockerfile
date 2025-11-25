FROM node:20-slim

WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./
RUN npm install --omit=dev

COPY src ./src

# Ensure node user owns the working directory before dropping privileges
RUN chown -R node:node /app
USER node

EXPOSE 4101

CMD ["node", "src/index.js"]
