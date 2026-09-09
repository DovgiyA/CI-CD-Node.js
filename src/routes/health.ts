import { Router } from "express";
import type { PrismaClient } from "@prisma/client";

export function createHealthRouter(db: PrismaClient): Router {
  const router = Router();

  router.get("/health", async (_req, res) => {
    try {
      await db.$queryRaw`SELECT 1`;
      res.status(200).json({ status: "ok" });
    } catch {
      res.status(503).json({ status: "unhealthy" });
    }
  });

  return router;
}
