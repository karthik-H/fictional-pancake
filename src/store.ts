import { createHmac, randomBytes, randomUUID, scrypt, timingSafeEqual } from "crypto";
import { promisify } from "util";
import type { Product, PublicUser, TokenPayload, User } from "./types";

const scryptAsync = promisify(scrypt);

const TOKEN_TTL_MS = 24 * 60 * 60 * 1000;
const tokenSecret = process.env.TOKEN_SECRET ?? "dev-only-change-me";

const usersByEmail = new Map<string, User>();
const productsById = new Map<string, Product>();

function seedProducts(): void {
  const samples: Array<Omit<Product, "id" | "createdAt">> = [
    {
      name: "Stoneware mug",
      description: "12 oz mug, speckled glaze.",
      priceCents: 1800,
      sku: "MUG-12",
    },
    {
      name: "Linen tea towel",
      description: "Washed linen, 18 x 28 in.",
      priceCents: 2400,
      sku: "TWL-LN",
    },
  ];

  for (const sample of samples) {
    const product: Product = {
      id: randomUUID(),
      createdAt: new Date().toISOString(),
      ...sample,
    };
    productsById.set(product.id, product);
  }
}

seedProducts();

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

export function findUserByEmail(email: string): User | undefined {
  return usersByEmail.get(email);
}

export async function createUser(input: {
  email: string;
  name: string;
  password: string;
}): Promise<User> {
  const user: User = {
    id: randomUUID(),
    email: input.email,
    name: input.name,
    passwordHash: await hashPassword(input.password),
  };
  usersByEmail.set(user.email, user);
  return user;
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

export function listProducts(): Product[] {
  return [...productsById.values()];
}

export function findProduct(id: string): Product | undefined {
  return productsById.get(id);
}

export function findProductBySku(sku: string): Product | undefined {
  for (const product of productsById.values()) {
    if (product.sku === sku) {
      return product;
    }
  }
  return undefined;
}

export function createProduct(input: {
  name: string;
  description: string;
  priceCents: number;
  sku: string;
}): Product {
  const product: Product = {
    id: randomUUID(),
    createdAt: new Date().toISOString(),
    ...input,
  };
  productsById.set(product.id, product);
  return product;
}
