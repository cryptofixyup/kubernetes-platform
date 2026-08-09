FROM oven/bun:1 as base
WORKDIR /app

COPY package.json bun.lockb* ./
RUN bun install

COPY src ./src

EXPOSE 3000
CMD ["bun", "run", "src/server.ts"]
