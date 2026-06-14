import crypto from 'node:crypto';
import fs from 'node:fs';

export function hashFile(filePath) {
  const buffer = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

export function hashText(text) {
  return crypto.createHash('sha256').update(text).digest('hex');
}
