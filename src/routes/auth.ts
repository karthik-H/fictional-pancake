import { Router } from "express";
import { createUser, findUserByEmail, signToken, toPublicUser, verifyPassword } from "../store";

export const authRouter = Router();

function readString(value: unknown): string | undefined {
  return typeof value === "string" ? value.trim() : undefined;
}

authRouter.post("/register", async (req, res) => {
  const email = readString(req.body?.email)?.toLowerCase();
  const name = readString(req.body?.name);
  const password = typeof req.body?.password === "string" ? req.body.password : undefined;

  if (!email || !email.includes("@") || !name || !password) {
    res.status(400).json({ error: "email, name, and password are required" });
    return;
  }

  if (password.length < 8) {
    res.status(400).json({ error: "password must be at least 8 characters" });
    return;
  }

  if (findUserByEmail(email)) {
    res.status(409).json({ error: "email is already registered" });
    return;
  }

  const user = await createUser({ email, name, password });
  res.status(201).json({ user: toPublicUser(user) });
});

authRouter.post("/login", async (req, res) => {
  const email = readString(req.body?.email)?.toLowerCase();
  const password = typeof req.body?.password === "string" ? req.body.password : undefined;

  if (!email || !password) {
    res.status(400).json({ error: "email and password are required" });
    return;
  }

  const user = findUserByEmail(email);
  if (!user || !(await verifyPassword(password, user.passwordHash))) {
    res.status(401).json({ error: "invalid email or password" });
    return;
  }

  res.json({ token: signToken(user), user: toPublicUser(user) });
});
