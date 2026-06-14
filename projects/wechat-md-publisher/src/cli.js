#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { loadArticle, printValidationResult, validateArticle } from './article.js';
import { loadEnv } from './load-env.js';
import { renderMarkdown, wrapPreviewHtml } from './markdown.js';
import { maskSensitive } from './safety.js';
import { toFileUrl } from './paths.js';
import { addDraft, getAccessToken, uploadArticleImage, uploadCover } from './wechat.js';

loadEnv();

function usage() {
  console.log(`Usage:
  npm run check -- articles/sample.md
  npm run preview -- articles/sample.md
  npm run draft -- articles/sample.md
`);
}

function ensureOk(article) {
  const result = validateArticle(article);
  const ok = printValidationResult(result);
  if (!ok) process.exit(1);
  return result;
}

async function commandCheck(filePath) {
  const article = loadArticle(filePath);
  ensureOk(article);
}

async function commandPreview(filePath) {
  const article = loadArticle(filePath);
  ensureOk(article);

  const content = await renderMarkdown(article.body, {
    articlePath: article.path,
    imageResolver: async (image) => toFileUrl(image.absolute),
  });

  const html = wrapPreviewHtml({
    title: article.meta.title,
    content,
  });

  const outDir = path.resolve(process.cwd(), '.preview');
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `${path.basename(article.path, '.md')}.html`);
  fs.writeFileSync(outPath, html, 'utf8');

  console.log(`Preview generated: ${outPath}`);
}

async function commandDraft(filePath) {
  const article = loadArticle(filePath);
  ensureOk(article);

  const accessToken = await getAccessToken();
  const thumbMediaId = await uploadCover(article.meta.coverPath, accessToken);
  const content = await renderMarkdown(article.body, {
    articlePath: article.path,
    imageResolver: async (image) => uploadArticleImage(image.absolute, accessToken),
  });
  const mediaId = await addDraft(article, content, thumbMediaId, accessToken);

  console.log('Draft created.');
  console.log(`Title: ${article.meta.title}`);
  console.log(`Draft media_id: ${mediaId}`);
  console.log('请到微信公众号后台草稿箱检查内容后再手动发布。');
}

async function main() {
  const [command, filePath] = process.argv.slice(2);
  if (!command || !filePath) {
    usage();
    process.exit(1);
  }

  if (command === 'check') return commandCheck(filePath);
  if (command === 'preview') return commandPreview(filePath);
  if (command === 'draft') return commandDraft(filePath);

  usage();
  process.exit(1);
}

main().catch((error) => {
  console.error(maskSensitive(error?.message || error));
  process.exit(1);
});
