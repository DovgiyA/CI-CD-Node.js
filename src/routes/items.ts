import { Router } from "express";
import type { PrismaClient } from "@prisma/client";
import { z } from "zod";

const createItemSchema = z.object({
  title: z.string().trim().min(1).max(200),
});

const updateItemSchema = z.object({
  title: z.string().trim().min(1).max(200),
});

export function createItemsRouter(db: PrismaClient): Router {
  const router = Router();

  router.get("/", async (_req, res) => {
    const items = await db.item.findMany({ orderBy: { createdAt: "desc" } });
    res.json(items);
  });

  router.get("/:id", async (req, res) => {
    const item = await db.item.findUnique({ where: { id: req.params.id } });
    if (!item) {
      res.status(404).json({ error: "Item not found" });
      return;
    }
    res.json(item);
  });

  router.post("/", async (req, res) => {
    const parsed = createItemSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid body", details: parsed.error.flatten() });
      return;
    }
    const item = await db.item.create({ data: { title: parsed.data.title } });
    res.status(201).json(item);
  });

  router.patch("/:id", async (req, res) => {
    const parsed = updateItemSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid body", details: parsed.error.flatten() });
      return;
    }

    try {
      const item = await db.item.update({
        where: { id: req.params.id },
        data: { title: parsed.data.title },
      });
      res.json(item);
    } catch {
      res.status(404).json({ error: "Item not found" });
    }
  });

  router.delete("/:id", async (req, res) => {
    try {
      await db.item.delete({ where: { id: req.params.id } });
      res.status(204).send();
    } catch {
      res.status(404).json({ error: "Item not found" });
    }
  });

  return router;
}
