import { access, readFile, readdir } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dataRoot = join(projectRoot, 'server-data');
const failures = [];
const requiredOrder = [
  'spawnmanager', 'baseevents', 'oxmysql', 'ox_lib', 'esx_lib',
  'es_extended', 'skinchanger', 'rp_core', 'rp_ui', 'rp_nativeui', 'rp_inventory',
  'cron', 'esx_addonaccount', 'esx_addoninventory', 'esx_datastore', 'esx_society',
  'rp_characters', 'rp_player', 'rp_organizations', 'rp_commerce', 'rp_phone', 'rp_vehicles', 'rp_banking',
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
const inventoryAccounts = /^\s*set\s+inventory:accounts\s+"\[\]"\s*(?:#.*)?$/m.exec(config);
if (!inventoryAccounts || inventoryAccounts.index > config.indexOf('ensure es_extended')) failures.push('server.cfg: set inventory:accounts "[]" must precede es_extended (ESX owns cash and bank accounts)');
if (!/^\s*set\s+onesync_population\s+"?false"?\s*(?:#.*)?$/m.test(config)) failures.push('server.cfg: set onesync_population false is required for an NPC-free world');
if (!/^\s*add_ace\s+resource\.rp_organizations\s+command\.save\s+allow\s*(?:#.*)?$/m.test(config)) failures.push('server.cfg: rp_organizations requires command.save permission for standard ESX persistence');
if (!/^\s*add_ace\s+resource\.rp_commerce\s+command\.save\s+allow\s*(?:#.*)?$/m.test(config)) failures.push('server.cfg: rp_commerce requires command.save permission for confirmed ESX payments');
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
if (resources.has('ox_inventory')) failures.push('Remove the competing ox_inventory resource directory: rp_inventory provides the ESX bridge alias');
for (const resource of requiredOrder) {
  const path = resources.get(resource);
  try {
    if (!path) throw new Error('missing');
    await access(join(path, 'fxmanifest.lua'));
  } catch {
    failures.push(`${resource}: resource or fxmanifest.lua is missing`);
  }
}

for (const conflicting of ['esx_multicharacter', 'esx_identity', 'esx_skin']) {
  if (starts.includes(conflicting)) failures.push(`${conflicting}: conflicts with rp_characters login/creator`);
}
const characterManifest = await readFile(join(dataRoot, 'resources', '[custom]', 'rp_characters', 'fxmanifest.lua'), 'utf8');
if (!characterManifest.includes("provide 'esx_multicharacter'")) failures.push('rp_characters: missing ESX multicharacter provider alias');
const inventoryManifest = await readFile(join(dataRoot, 'resources', '[custom]', 'rp_inventory', 'fxmanifest.lua'), 'utf8');
if (!inventoryManifest.includes("provide 'ox_inventory'")) failures.push('rp_inventory: missing ESX custom-inventory provider alias');
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
