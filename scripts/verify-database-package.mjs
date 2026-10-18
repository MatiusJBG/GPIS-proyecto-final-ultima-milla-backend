import process from 'node:process';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve, sep } from 'node:path';
import { fileURLToPath, URL } from 'node:url';

export function verifyDatabasePackage(directory) {
  const root = resolve(directory);
  const entries = JSON.parse(readFileSync(new URL('../database/original-checksums.json',import.meta.url),'utf8'));
  for (const entry of entries) {
    const path = resolve(root,entry.path);
    if (!path.startsWith(root+sep)) throw new Error('Ruta de paquete fuera de su raíz.');
    const hash = createHash('sha256').update(readFileSync(path)).digest('hex');
    if (hash !== entry.sha256) throw new Error(`El archivo original cambió: ${entry.path}`);
  }
  return entries.length;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const count = verifyDatabasePackage(process.env.DATABASE_PACKAGE_DIR || process.cwd());
  process.stdout.write(`Paquete original verificado: ${count} archivos coinciden con sus SHA-256.\n`);
}
