import { beforeEach, describe, expect, it, vi } from "vitest";
import request from "supertest";
import type { PrismaClient } from "@prisma/client";
import { createApp } from "../src/app.js";

function createMockDb() {
  const item = {
    findMany: vi.fn(),
    findUnique: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
  };

  const db = {
    item,
    $queryRaw: vi.fn(),
  } as unknown as PrismaClient;

  return { db, item };
}

describe("health", () => {
  it("returns 200 when database responds", async () => {
    const { db } = createMockDb();
    (db.$queryRaw as ReturnType<typeof vi.fn>).mockResolvedValue([{ "?column?": 1 }]);
    const app = createApp(db);

    const res = await request(app).get("/health");
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: "ok" });
  });

  it("returns 503 when database is down", async () => {
    const { db } = createMockDb();
    (db.$queryRaw as ReturnType<typeof vi.fn>).mockRejectedValue(new Error("db down"));
    const app = createApp(db);

    const res = await request(app).get("/health");
    expect(res.status).toBe(503);
    expect(res.body).toEqual({ status: "unhealthy" });
  });
});

describe("items", () => {
  const sample = {
    id: "clx123",
    title: "First",
    createdAt: new Date("2026-09-09T00:00:00.000Z"),
  };

  let db: PrismaClient;
  let item: ReturnType<typeof createMockDb>["item"];

  beforeEach(() => {
    ({ db, item } = createMockDb());
  });

  it("lists items", async () => {
    item.findMany.mockResolvedValue([sample]);
    const res = await request(createApp(db)).get("/items");
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].title).toBe("First");
  });

  it("creates an item", async () => {
    item.create.mockResolvedValue(sample);
    const res = await request(createApp(db))
      .post("/items")
      .send({ title: "First" });
    expect(res.status).toBe(201);
    expect(res.body.title).toBe("First");
  });

  it("rejects empty title", async () => {
    const res = await request(createApp(db)).post("/items").send({ title: "  " });
    expect(res.status).toBe(400);
  });

  it("returns one item by id", async () => {
    item.findUnique.mockResolvedValue(sample);
    const res = await request(createApp(db)).get("/items/clx123");
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ id: "clx123", title: "First" });
  });

  it("returns 404 for missing item", async () => {
    item.findUnique.mockResolvedValue(null);
    const res = await request(createApp(db)).get("/items/missing");
    expect(res.status).toBe(404);
  });

  it("updates an item", async () => {
    item.update.mockResolvedValue({ ...sample, title: "Updated" });
    const res = await request(createApp(db))
      .patch("/items/clx123")
      .send({ title: "Updated" });
    expect(res.status).toBe(200);
    expect(res.body.title).toBe("Updated");
  });

  it("deletes an item", async () => {
    item.delete.mockResolvedValue(sample);
    const res = await request(createApp(db)).delete("/items/clx123");
    expect(res.status).toBe(204);
  });
});
