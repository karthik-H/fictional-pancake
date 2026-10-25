import express from "express";
import { authRouter } from "./routes/auth";
import { productsRouter } from "./routes/products";

export function createApp(): express.Express {
  const app = express();
  app.use(express.json());
  app.use("/auth", authRouter);
  app.use("/products", productsRouter);
  return app;
}
