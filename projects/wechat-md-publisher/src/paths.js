import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function projectPath(...parts) {
  return path.resolve(process.cwd(), ...parts);
}

export function resolveArticlePath(input) {
  if (!input) {
    throw new Error('请提供 Markdown 文件路径，例如：npm run check -- articles/sample.md');
  }
  return path.resolve(process.cwd(), input);
}

export function resolveFromArticle(articlePath, maybeRelativePath) {
  if (!maybeRelativePath) return null;
  if (/^https?:\/\//i.test(maybeRelativePath)) return maybeRelativePath;
  if (path.isAbsolute(maybeRelativePath)) return maybeRelativePath;
  return path.resolve(path.dirname(articlePath), maybeRelativePath);
}

export function toFileUrl(filePath) {
  return pathToFileURL(filePath).href;
}
