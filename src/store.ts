import { createHmac, randomBytes, randomUUID, scrypt, timingSafeEqual } from "crypto";
import { promisify } from "util";
import { pool } from "./db";
import type { Product, PublicUser, TokenPayload, User } from "./types";

const scryptAsync = promisify(scrypt);

const TOKEN_TTL_MS = 24 * 60 * 60 * 1000;
const tokenSecret = process.env.TOKEN_SECRET ?? "dev-only-change-me";

type UserRow = {
  id: string;
  email: string;
  name: string;
  password_hash: string;
};

type ProductRow = {
  id: string;
  name: string;
  description: string;
  price_cents: number;
  sku: string;
  created_at: Date | string;
};

export class ConflictError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ConflictError";
  }
}

function mapUser(row: UserRow): User {
  return {
    id: row.id,
    email: row.email,
    name: row.name,
    passwordHash: row.password_hash,
  };
}

function mapProduct(row: ProductRow): Product {
  const createdAt = row.created_at instanceof Date ? row.created_at.toISOString() : row.created_at;
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    priceCents: Number(row.price_cents),
    sku: row.sku,
    createdAt,
  };
}

function isUniqueViolation(err: unknown): boolean {
  return typeof err === "object" && err !== null && "code" in err && err.code === "23505";
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function toPublicUser(user: User): PublicUser {
  return { id: user.id, email: user.email, name: user.name };
}

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16).toString("hex");
  const derived = (await scryptAsync(password, salt, 64)) as Buffer;
  return `${salt}:${derived.toString("hex")}`;
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [salt, hash] = stored.split(":");
  if (!salt || !hash) {
    return false;
  }

  const derived = (await scryptAsync(password, salt, 64)) as Buffer;
  const hashBuf = Buffer.from(hash, "hex");
  if (hashBuf.length !== derived.length) {
    return false;
  }

  return timingSafeEqual(hashBuf, derived);
}

export async function findUserByEmail(email: string): Promise<User | undefined> {
  const result = await pool.query<UserRow>(
    "SELECT id, email, name, password_hash FROM users WHERE email = $1",
    [email],
  );
  const row = result.rows[0];
  return row ? mapUser(row) : undefined;
}

export async function createUser(input: {
  email: string;
  name: string;
  password: string;
}): Promise<User> {
  const passwordHash = await hashPassword(input.password);
  try {
    const result = await pool.query<UserRow>(
      `INSERT INTO users (id, email, name, password_hash)
       VALUES ($1, $2, $3, $4)
       RETURNING id, email, name, password_hash`,
      [randomUUID(), input.email, input.name, passwordHash],
    );
    return mapUser(result.rows[0]);
  } catch (err) {
    if (isUniqueViolation(err)) {
      throw new ConflictError("email is already registered");
    }
    throw err;
  }
}

export function signToken(user: User): string {
  const payload: TokenPayload = {
    sub: user.id,
    email: user.email,
    exp: Date.now() + TOKEN_TTL_MS,
  };
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const signature = createHmac("sha256", tokenSecret).update(body).digest("base64url");
  return `${body}.${signature}`;
}

export function verifyToken(token: string): TokenPayload | null {
  const [body, signature] = token.split(".");
  if (!body || !signature) {
    return null;
  }

  const expected = createHmac("sha256", tokenSecret).update(body).digest("base64url");
  const actualBuf = Buffer.from(signature);
  const expectedBuf = Buffer.from(expected);
  if (actualBuf.length !== expectedBuf.length || !timingSafeEqual(actualBuf, expectedBuf)) {
    return null;
  }

  try {
    const payload = JSON.parse(Buffer.from(body, "base64url").toString("utf8")) as TokenPayload;
    if (typeof payload.exp !== "number" || payload.exp < Date.now()) {
      return null;
    }
    if (typeof payload.sub !== "string" || typeof payload.email !== "string") {
      return null;
    }
    return payload;
  } catch {
    return null;
  }
}

export async function listProducts(): Promise<Product[]> {
  const result = await pool.query<ProductRow>(
    `SELECT id, name, description, price_cents, sku, created_at
     FROM products
     ORDER BY created_at ASC, sku ASC`,
  );
  return result.rows.map(mapProduct);
}

export async function findProduct(id: string): Promise<Product | undefined> {
  if (!uuidPattern.test(id)) {
    return undefined;
  }
  const result = await pool.query<ProductRow>(
    `SELECT id, name, description, price_cents, sku, created_at
     FROM products
     WHERE id = $1`,
    [id],
  );
  const row = result.rows[0];
  return row ? mapProduct(row) : undefined;
}

export async function findProductBySku(sku: string): Promise<Product | undefined> {
  const result = await pool.query<ProductRow>(
    `SELECT id, name, description, price_cents, sku, created_at
     FROM products
     WHERE sku = $1`,
    [sku],
  );
  const row = result.rows[0];
  return row ? mapProduct(row) : undefined;
}

export async function createProduct(input: {
  name: string;
  description: string;
  priceCents: number;
  sku: string;
}): Promise<Product> {
  try {
    const result = await pool.query<ProductRow>(
      `INSERT INTO products (id, name, description, price_cents, sku, created_at)
       VALUES ($1, $2, $3, $4, $5, now())
       RETURNING id, name, description, price_cents, sku, created_at`,
      [randomUUID(), input.name, input.description, input.priceCents, input.sku],
    );
    return mapProduct(result.rows[0]);
  } catch (err) {
    if (isUniqueViolation(err)) {
      throw new ConflictError("sku is already cataloged");
    }
    throw err;
  }
}
