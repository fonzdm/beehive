// Blossom 6.2.x couples uploader rules to mandatory expiry and has no prune
// disable switch. Use its stock server/storage/workers without starting pruning.
// Review this adapter against upstream main.ts before widening the image policy.
import { loadConfig } from "/app/src/config/loader.ts";
import { initDb } from "/app/src/db/client.ts";
import { LocalStorage } from "/app/src/storage/local.ts";
import { initPool } from "/app/src/workers/pool.ts";
import { buildApp } from "/app/src/server.ts";

const configPath = "/config/config.yml";
await Deno.stat(configPath); // Do not fall back to upstream's public defaults.
const config = await loadConfig(configPath);
if (config.storage.backend !== "local" || config.database.url || config.dashboard.enabled) {
  throw new Error("Bootstrap supports local storage/database and no dashboard only");
}
const db = await initDb(config.database);
const storage = new LocalStorage(config.storage.local!.dir);
await storage.setup();
const pool = initPool(
  config.upload.workers, config.upload.maxJobsPerWorker,
  config.upload.throughputWindowMs, db, config.database,
);
const app = await buildApp(db, storage, config);
const server = Deno.serve({ hostname: config.host, port: config.port }, app.fetch);
console.log("Blossom ready; automatic pruning disabled by bootstrap");

let stopping = false;
const shutdown = async () => {
  if (stopping) return;
  stopping = true;
  await server.shutdown();
  pool.shutdown();
  db.close();
  Deno.exit(0);
};
Deno.addSignalListener("SIGTERM", shutdown);
Deno.addSignalListener("SIGINT", shutdown);
