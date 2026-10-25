# fictional-pancake

TypeScript ecommerce service. Accounts register and log in, and signed-in users can add products to the catalog. Anyone can read the catalog.

Accounts and products are stored in PostgreSQL. Passwords are scrypt hashes. Login returns a bearer token that lasts 24 hours. Set `TOKEN_SECRET` before running anywhere other than local development.

## Run

Start Postgres, then the service. The compose file uses database `pancake` with user and password `pancake`, and publishes it on host port 5433.

```bash
npm install
docker compose up -d
export DATABASE_URL=postgres://pancake:pancake@localhost:5433/pancake
npm run dev
```

`DATABASE_URL` is required. The server listens on port 3000, or `PORT` if that is set. On startup the service creates the `users` and `products` tables and inserts the two sample products if those SKUs are not already present.

## Endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/auth/register` | no | Create an account |
| POST | `/auth/login` | no | Return a bearer token |
| GET | `/products` | no | List the catalog |
| GET | `/products/:id` | no | Read one product |
| POST | `/products` | bearer token | Add a product to the catalog |

Register:

```bash
curl -s -X POST http://localhost:3000/auth/register \
  -H 'content-type: application/json' \
  -d '{"email":"ada@example.com","name":"Ada","password":"password123"}'
```

Login:

```bash
curl -s -X POST http://localhost:3000/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"ada@example.com","password":"password123"}'
```

Catalog a product (use the token from login):

```bash
curl -s -X POST http://localhost:3000/products \
  -H 'content-type: application/json' \
  -H 'authorization: Bearer TOKEN' \
  -d '{"name":"Ceramic bowl","description":"Small serving bowl","priceCents":3200,"sku":"BWL-01"}'
```

Read products:

```bash
curl -s http://localhost:3000/products
curl -s http://localhost:3000/products/PRODUCT_ID
```
