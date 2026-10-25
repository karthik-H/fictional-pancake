import express, { type NextFunction, type Request, type Response } from "express";
import { authRouter } from "./routes/auth";
import { productsRouter } from "./routes/products";

export function createApp(): express.Express {
  const app = express();
  app.use(express.json());
  app.use("/auth", authRouter);
  app.use("/products", productsRouter);
  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    console.error(err);
    if (!res.headersSent) {
      res.status(500).json({ error: "internal error" });
    }
  });
  return app;
}
