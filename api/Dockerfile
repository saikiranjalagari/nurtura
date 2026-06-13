FROM node:20-slim
WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src

ENV NODE_ENV=production
ENV DISABLE_EMBEDDED_PG=true
EXPOSE 3000

CMD ["node", "src/index.js"]
