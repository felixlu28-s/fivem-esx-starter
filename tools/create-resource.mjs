import { cp, mkdir, readFile, readdir, stat, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const toolDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(toolDirectory, '..');
const resourceName = process.argv[2];
const outputRoot = process.argv[3]
  ? resolve(process.argv[3])
  : join(projectRoot, 'server-data', 'resources', '[custom]');

if (!resourceName || !/^rp_[a-z][a-z0-9_]*$/.test(resourceName)) {
  console.error('Usage: npm run resource:new -- rp_resource_name [optional-output-directory]');
  process.exitCode = 1;
} else {
  const templateDirectory = join(projectRoot, 'templates', 'resource');
  const targetDirectory = join(outputRoot, resourceName);

  try {
    await stat(targetDirectory);
    console.error(`Resource already exists: ${targetDirectory}`);
    process.exitCode = 1;
  } catch {
    await mkdir(outputRoot, { recursive: true });
    await cp(templateDirectory, targetDirectory, { recursive: true, errorOnExist: true });
    await replaceTokens(targetDirectory, '__RESOURCE__', resourceName);
    console.log(`Created ${targetDirectory}`);
  }
}

async function replaceTokens(directory, token, replacement) {
  const entries = await readdir(directory, { withFileTypes: true });

  for (const entry of entries) {
    const path = join(directory, entry.name);

    if (entry.isDirectory()) {
      await replaceTokens(path, token, replacement);
      continue;
    }

    const content = await readFile(path, 'utf8');
    await writeFile(path, content.replaceAll(token, replacement));
  }
}
