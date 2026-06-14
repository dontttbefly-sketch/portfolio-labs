import fs from 'node:fs';
import path from 'node:path';

const CACHE_DIR = path.resolve(process.cwd(), '.cache');

function ensureCacheDir() {
  fs.mkdirSync(CACHE_DIR, { recursive: true });
}

export function readCache(name, fallback = null) {
  const filePath = path.join(CACHE_DIR, name);
  if (!fs.existsSync(filePath)) return fallback;
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return fallback;
  }
}

export function writeCache(name, value) {
  ensureCacheDir();
  const filePath = path.join(CACHE_DIR, name);
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

export function updateCache(name, updater) {
  const current = readCache(name, {});
  const next = updater(current);
  writeCache(name, next);
  return next;
}
