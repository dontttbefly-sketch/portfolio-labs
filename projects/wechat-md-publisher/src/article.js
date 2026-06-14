import fs from 'node:fs';
import path from 'node:path';
import { parseFrontmatter } from './frontmatter.js';
import { collectLocalImages } from './markdown.js';
import { projectPath, resolveArticlePath, resolveFromArticle } from './paths.js';
import { scanSensitiveText } from './safety.js';

export function loadArticle(inputPath) {
  const articlePath = resolveArticlePath(inputPath);
  if (!fs.existsSync(articlePath)) {
    throw new Error(`Markdown 文件不存在：${articlePath}`);
  }
  if (path.extname(articlePath).toLowerCase() !== '.md') {
    throw new Error(`只支持 .md 文件：${articlePath}`);
  }

  const raw = fs.readFileSync(articlePath, 'utf8');
  const { data, body } = parseFrontmatter(raw);
  const defaultCover = process.env.WECHAT_DEFAULT_COVER || 'assets/default-cover.png';
  const defaultAuthor = process.env.WECHAT_AUTHOR || '空杯';
  const coverValue = data.cover || defaultCover;
  const coverPath = data.cover ? resolveFromArticle(articlePath, coverValue) : projectPath(coverValue);

  return {
    path: articlePath,
    raw,
    body,
    meta: {
      title: data.title || '',
      digest: data.digest || '',
      author: data.author || defaultAuthor,
      cover: coverValue,
      coverPath,
      sourceUrl: data.source_url || '',
      showCoverPic: data.show_cover_pic === true || data.show_cover_pic === 'true',
    },
  };
}

export function validateArticle(article) {
  const errors = [];
  const warnings = [];

  if (!article.meta.title) errors.push('缺少 frontmatter 字段：title');
  if (!article.meta.digest) errors.push('缺少 frontmatter 字段：digest');
  if (!article.meta.author) warnings.push('缺少 author，将使用全局默认作者。');
  if (article.meta.digest && article.meta.digest.length > 120) {
    warnings.push(`digest 当前 ${article.meta.digest.length} 字，建议控制在 60-120 字。`);
  }

  if (!article.meta.coverPath || !fs.existsSync(article.meta.coverPath)) {
    errors.push(`封面图不存在：${article.meta.coverPath || article.meta.cover}`);
  }

  for (const image of collectLocalImages(article.body, article.path)) {
    if (!image.absolute || !fs.existsSync(image.absolute)) {
      errors.push(`正文图片不存在：${image.original}`);
    }
  }

  const findings = scanSensitiveText(article.raw);
  for (const finding of findings) {
    warnings.push(`疑似敏感信息：${finding.type} -> ${finding.value}`);
  }

  return { errors, warnings };
}

export function printValidationResult({ errors, warnings }) {
  if (warnings.length) {
    console.log('Warnings:');
    for (const warning of warnings) console.log(`- ${warning}`);
  }

  if (errors.length) {
    console.log('Errors:');
    for (const error of errors) console.log(`- ${error}`);
    return false;
  }

  console.log('Article check passed.');
  return true;
}
