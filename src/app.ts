import express from "express";
import type { PrismaClient } from "@prisma/client";
import { createHealthRouter } from "./routes/health.js";
import { createItemsRouter } from "./routes/items.js";

export function createApp(db: PrismaClient) {
  const app = express();

  app.disable("x-powered-by");
  app.use(express.json({ limit: "32kb" }));

  app.use(createHealthRouter(db));
  app.use("/items", createItemsRouter(db));

  app.use(
    (
      err: unknown,
      _req: express.Request,
      res: express.Response,
      _next: express.NextFunction,
    ) => {
      console.error(JSON.stringify({ level: "error", msg: "unhandled_error", err: String(err) }));
      res.status(500).json({ error: "Internal server error" });
    },
  );

  return app;
}
