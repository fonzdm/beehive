// The relay requires its own signing identity even when statistics are disabled.
// Persist it in the relay's small state volume; never use the user's Amber key.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { generateSecretKey, nip19 } from 'nostr-tools';
const keyDir = '/state/ditto';
mkdirSync(keyDir, { recursive: true, mode: 0o700 });
const keyFile = `${keyDir}/nsec`;
try {
  writeFileSync(keyFile, nip19.nsecEncode(generateSecretKey()), { flag: 'wx', mode: 0o600 });
} catch (error) {
  if ((error as NodeJS.ErrnoException).code !== 'EEXIST') throw error;
}
process.env.NOSTR_NSEC = readFileSync(keyFile, 'utf8').trim();
// Wait for the separate OpenSearch service before upstream starts migrations.
const databaseUrl = process.env.OPENSEARCH_NODE;
if (!databaseUrl) throw new Error('OPENSEARCH_NODE is required');
const databaseAuth = 'Basic ' + Buffer.from(
  `${process.env.OPENSEARCH_USERNAME}:${process.env.OPENSEARCH_PASSWORD}`,
).toString('base64');
let ready = false;
for (let attempt = 0; attempt < 120; attempt++) {
  try {
    const response = await fetch(`${databaseUrl}/_cluster/health`, {
      headers: { Authorization: databaseAuth }, signal: AbortSignal.timeout(2000),
    });
    const health = await response.json() as { status?: string };
    if (response.ok && ['green', 'yellow'].includes(health.status ?? '')) { ready = true; break; }
  } catch { /* Database is still starting. */ }
  await Bun.sleep(1000);
}
if (!ready) throw new Error('OpenSearch did not become ready');
// Bun workers inherit the process's initial environment, so start a child with
// the generated key exported before upstream creates its protocol workers.
const relay = Bun.spawn([process.execPath, '/app/src/server.ts'], {
  env: process.env, stdin: 'inherit', stdout: 'inherit', stderr: 'inherit',
});
process.on('SIGTERM', () => relay.kill('SIGTERM'));
process.on('SIGINT', () => relay.kill('SIGINT'));
process.exit(await relay.exited);
