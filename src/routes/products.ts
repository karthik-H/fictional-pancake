import { Router } from "express";
import { asyncHandler } from "../asyncHandler";
import { requireAuth, type AuthedRequest } from "../middleware/requireAuth";
import { ConflictError, createProduct, findProduct, findProductBySku, listProducts } from "../store";

export const productsRouter = Router();

function readString(value: unknown): string | undefined {
  return typeof value === "string" ? value.trim() : undefined;
}

productsRouter.get(
  "/",
  asyncHandler(async (_req, res) => {
    res.json({ products: await listProducts() });
  }),
);

productsRouter.get(
  "/:id",
  asyncHandler(async (req, res) => {
    const product = await findProduct(req.params.id);
    if (!product) {
      res.status(404).json({ error: "product not found" });
      return;
    }
    res.json({ product });
  }),
);

productsRouter.post(
  "/",
  requireAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    const name = readString(req.body?.name);
    const description = readString(req.body?.description) ?? "";
    const sku = readString(req.body?.sku);
    const priceCents = req.body?.priceCents;

    if (!name || !sku || typeof priceCents !== "number" || !Number.isInteger(priceCents) || priceCents < 0) {
      res.status(400).json({
        error: "name, sku, and an integer priceCents of 0 or more are required",
      });
      return;
    }

    if (await findProductBySku(sku)) {
      res.status(409).json({ error: "sku is already cataloged" });
      return;
    }

    try {
      const product = await createProduct({ name, description, priceCents, sku });
      res.status(201).json({ product });
    } catch (err) {
      if (err instanceof ConflictError) {
        res.status(409).json({ error: err.message });
        return;
      }
      throw err;
    }
  }),
);
