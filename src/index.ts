import { createApp } from "./app";
import { initDb } from "./db";

const port = Number(process.env.PORT ?? 3000);

async function main(): Promise<void> {
  await initDb();
  const app = createApp();
  app.listen(port, () => {
    console.log(`ecommerce service listening on http://localhost:${port}`);
  });
}

main().catch((err: unknown) => {
  console.error(err);
  process.exit(1);
});
