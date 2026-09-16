import { readFile, readdir } from 'node:fs/promises';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import luaparse from 'luaparse';

const toolDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(toolDirectory, '..');
const resourcesRoot = join(projectRoot, 'server-data', 'resources', '[custom]');
const templateRoot = join(projectRoot, 'templates', 'resource');
const failures = [];

await checkLuaSyntax(resourcesRoot);
await checkLuaSyntax(templateRoot);

for (const resourceName of await readdir(resourcesRoot)) {
  if (!resourceName.startsWith('rp_')) {
    failures.push(`${resourceName}: custom resource names must start with rp_`);
    continue;
  }

  const manifestPath = join(resourcesRoot, resourceName, 'fxmanifest.lua');
  let manifest;

  try {
    manifest = await readFile(manifestPath, 'utf8');
  } catch {
    failures.push(`${resourceName}: missing fxmanifest.lua`);
    continue;
  }

  for (const required of ["fx_version 'cerulean'", "game 'gta5'", "version '"]) {
    if (!manifest.includes(required)) failures.push(`${resourceName}: manifest is missing ${required}`);
  }

  if (/RegisterNetEvent\(['\"](?!rp_)/.test(await readResourceLua(join(resourcesRoot, resourceName)))) {
    failures.push(`${resourceName}: found a RegisterNetEvent that is not prefixed with rp_`);
  }
}

if (failures.length > 0) {
  console.error(failures.map((failure) => `- ${failure}`).join('\n'));
  process.exitCode = 1;
} else {
  console.log(`Validated custom resources in ${relative(projectRoot, resourcesRoot)}`);
}

async function readResourceLua(directory) {
  const chunks = [];

  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);

    if (entry.isDirectory()) {
      if (entry.name !== 'web') chunks.push(await readResourceLua(path));
    } else if (entry.name.endsWith('.lua')) {
      chunks.push(await readFile(path, 'utf8'));
    }
  }

  return chunks.join('\n');
}

async function checkLuaSyntax(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);

    if (entry.isDirectory()) {
      if (entry.name !== 'web') await checkLuaSyntax(path);
      continue;
    }

    if (!entry.name.endsWith('.lua')) continue;

    try {
      luaparse.parse(await readFile(path, 'utf8'), { luaVersion: '5.3' });
    } catch (error) {
      failures.push(`${relative(projectRoot, path)}: ${error.message}`);
    }
  }
}
