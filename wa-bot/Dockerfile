FROM node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY bot.js ./

RUN mkdir -p /app/storage/wa_auth && chmod -R 777 /app/storage

ENV NODE_ENV=production
ENV PORT=7860
ENV STORAGE_DIR=/app/storage
ENV API_BASE=https://voice-expense-tracker-olive.vercel.app/api.php

EXPOSE 7860

CMD ["node", "bot.js"]
