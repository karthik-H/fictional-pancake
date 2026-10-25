import type { NextFunction, Request, Response } from "express";
import { verifyToken } from "../store";

export type AuthedRequest = Request & {
  userId?: string;
};

export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction): void {
  const header = req.header("authorization");
  if (!header || !header.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing bearer token" });
    return;
  }

  const payload = verifyToken(header.slice("Bearer ".length).trim());
  if (!payload) {
    res.status(401).json({ error: "Invalid or expired token" });
    return;
  }

  req.userId = payload.sub;
  next();
}
