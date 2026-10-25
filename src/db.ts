import { Pool } from "pg";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  throw new Error("DATABASE_URL is required");
}

export const pool = new Pool({ connectionString: databaseUrl });

export async function initDb(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      password_hash TEXT NOT NULL
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS products (
      id UUID PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT NOT NULL,
      price_cents INTEGER NOT NULL CHECK (price_cents >= 0),
      sku TEXT UNIQUE NOT NULL,
      created_at TIMESTAMPTZ NOT NULL
    )
  `);

  await pool.query(
    `
      INSERT INTO products (id, name, description, price_cents, sku, created_at)
      VALUES
        (gen_random_uuid(), $1, $2, $3, $4, now()),
        (gen_random_uuid(), $5, $6, $7, $8, now())
      ON CONFLICT (sku) DO NOTHING
    `,
    [
      "Stoneware mug",
      "12 oz mug, speckled glaze.",
      1800,
      "MUG-12",
      "Linen tea towel",
      "Washed linen, 18 x 28 in.",
      2400,
      "TWL-LN",
    ],
  );
}
