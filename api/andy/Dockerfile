FROM node:22.9.0-slim

ENV NODE_ENV=production
ENV PORT=3000

COPY . /app
WORKDIR /app

RUN npm install

CMD ["npm", "run", "start"]