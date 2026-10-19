import { spawnSync } from 'node:child_process';
import process from 'node:process';
import { mkdtempSync, writeFileSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { verifyDatabasePackage } from './verify-database-package.mjs';

const packagePath = process.env.DATABASE_PACKAGE_DIR;
verifyDatabasePackage(packagePath);
const project = `logistica_api_${process.pid}_${Date.now()}`;
const temp = mkdtempSync(join(tmpdir(), 'logistica-api-'));
const override = join(temp, 'ports.yaml');
writeFileSync(override, 'services:\n  postgres:\n    ports:\n      - "127.0.0.1::5432"\n');
const docker = process.platform === 'win32' ? 'docker.exe' : 'docker';
const args = ['compose','-p',project,'-f',resolve(packagePath,'compose.test.yaml'),'-f',override];
function run(command, commandArgs, capture = false, env = process.env) {
  const result = spawnSync(command,commandArgs,{stdio:capture?'pipe':'inherit',encoding:'utf8',env,timeout:180_000});
  if (result.error || result.status !== 0) {
    if (capture) process.stderr.write(result.stderr ?? '');
    throw new Error(`Falló ${command}; código ${result.status ?? 'sin salida'}.`);
  }
  return result.stdout?.trim();
}
let started = false;
try {
  // Original image, init, migrations, roles and SQL tests; only publish a temporary host port.
  started = true;
  run(docker,[...args,'up','-d','--wait','postgres']);
  // The original concurrency runner opens new admin sessions; choose their schema per session.
  run(docker,[...args,'run','--rm','-e','PGOPTIONS=-csearch_path=logistica,pg_catalog','tests']);
  const address = run(docker,[...args,'port','postgres','5432'],true);
  const match = /^127\.0\.0\.1:(\d+)$/.exec(address ?? '');
  if (!match) throw new Error('La base de pruebas debe publicar únicamente localhost.');
  const container = run(docker,[...args,'ps','-q','postgres'],true);
  const env = {
    ...process.env,
    TEST_DATABASE_URL:`postgresql://logistica_app:app_test_only@127.0.0.1:${match[1]}/logistica_test`,
    TEST_DATABASE_CONTAINER:container,
    TEST_DATABASE_PROJECT:project,
  };
  run(process.execPath,['--experimental-vm-modules','node_modules/jest/bin/jest.js','--config','jest.integration.config.js','--runInBand'],false,env);
} finally {
  if (started) run(docker,[...args,'down']);
  unlinkSync(override);
  rmdirSync(temp);
}
