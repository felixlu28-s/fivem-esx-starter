import { access, readFile, readdir } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dataRoot = join(projectRoot, 'server-data');
const failures = [];
const requiredOrder = [
  'spawnmanager', 'baseevents', 'oxmysql', 'ox_lib', 'esx_lib',
  'es_extended', 'skinchanger', 'rp_core', 'rp_characters', 'rp_ui',
];
let config;
try {
  config = await readFile(join(dataRoot, 'server.cfg'), 'utf8');
} catch {
  console.error('Missing server-data/server.cfg. Copy server.cfg.example and configure it locally.');
  process.exit(1);
}

// Only inspect resource names; never print configuration values or credentials.
const starts = [...config.matchAll(/^\s*(?:ensure|start)\s+["']?([\w-]+)["']?\s*(?:#.*)?$/gm)]
  .map((match) => match[1]);
let previousIndex = -1;
for (const resource of requiredOrder) {
  const index = starts.indexOf(resource);
  if (index === -1) {
    failures.push(`server.cfg: missing explicit ensure ${resource}`);
  } else if (index <= previousIndex) {
    failures.push(`server.cfg: ${resource} is out of order; follow server.cfg.example`);
  } else {
    previousIndex = index;
  }
}

const resources = new Map();
async function collectResources(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const path = join(directory, entry.name);
    if (entry.name.startsWith('[')) {
      await collectResources(path);
    } else {
      resources.set(entry.name, path);
    }
  }
}
await collectResources(join(dataRoot, 'resources'));
for (const resource of requiredOrder) {
  const path = resources.get(resource);
  try {
    if (!path) throw new Error('missing');
    await access(join(path, 'fxmanifest.lua'));
  } catch {
    failures.push(`${resource}: resource or fxmanifest.lua is missing`);
  }
}

// ESX detects multicharacter by folder presence, even when it is not ensured.
if (resources.has('esx_multicharacter')) {
  failures.push('esx_multicharacter is installed: this starter currently supports ESX single-character login only');
}
for (const [resource, file] of [
  ['esx_lib', 'imports.lua'],
  ['skinchanger', 'client/main.lua'],
  ['skinchanger', 'config.lua'],
  ['oxmysql', 'lib/MySQL.lua'],
  ['ox_lib', 'init.lua'],
  ['rp_ui', 'web/dist/index.html'],
]) {
  const path = resources.get(resource);
  if (!path) continue;
  try {
    await access(join(path, file));
  } catch {
    failures.push(`${resource}: missing ${file}${resource === 'rp_ui' ? '; run npm run ui:build' : ''}`);
  }
}

if (failures.length) {
  console.error(failures.map((failure) => `- ${failure}`).join('\n'));
  process.exitCode = 1;
} else {
  console.log('Local runtime files, explicit resource start order and NUI entry point validated.');
  console.log('Database connectivity, running resource state and a real FiveM join still require live verification.');
}
