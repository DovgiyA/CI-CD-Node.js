import { createApp } from "./app.js";
import { prisma } from "./db.js";

const port = Number(process.env.PORT ?? 3000);

if (!Number.isFinite(port) || port <= 0) {
  console.error(JSON.stringify({ level: "error", msg: "invalid_port", port: process.env.PORT }));
  process.exit(1);
}

const app = createApp(prisma);

const server = app.listen(port, "0.0.0.0", () => {
  console.log(
    JSON.stringify({
      level: "info",
      msg: "server_started",
      port,
      nodeEnv: process.env.NODE_ENV ?? "development",
    }),
  );
});

async function shutdown(signal: string) {
  console.log(JSON.stringify({ level: "info", msg: "shutdown", signal }));
  server.close(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
}

process.on("SIGTERM", () => void shutdown("SIGTERM"));
process.on("SIGINT", () => void shutdown("SIGINT"));
