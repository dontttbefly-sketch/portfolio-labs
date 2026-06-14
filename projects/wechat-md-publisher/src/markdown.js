import fs from 'node:fs';
import path from 'node:path';
import { resolveFromArticle, toFileUrl } from './paths.js';

const COLORS = {
  text: '#2f3437',
  muted: '#6b7280',
  border: '#e5e7eb',
  codeBg: '#f6f8fa',
  quoteBg: '#f8fafc',
  accent: '#1f6feb',
};

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function isTableSeparator(line) {
  return /^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$/.test(line);
}

function splitTableRow(line) {
  return line
    .trim()
    .replace(/^\|/, '')
    .replace(/\|$/, '')
    .split('|')
    .map((cell) => cell.trim());
}

function isBlockStart(line) {
  return (
    /^#{1,6}\s+/.test(line) ||
    /^>\s?/.test(line) ||
    /^[-*+]\s+/.test(line) ||
    /^\d+\.\s+/.test(line) ||
    /^```/.test(line) ||
    line.trim() === ''
  );
}

function renderInline(text, context) {
  let output = escapeHtml(text);

  output = output.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_, alt, src) => {
    const resolved = context.imageMap.get(src) ?? src;
    return `<img src="${escapeHtml(resolved)}" alt="${escapeHtml(alt)}" style="max-width:100%;display:block;margin:18px auto;border-radius:8px;" />`;
  });

  output = output.replace(/\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g, (_, label, href) => {
    return `<a href="${escapeHtml(href)}" style="color:${COLORS.accent};text-decoration:none;">${escapeHtml(label)}</a>`;
  });

  output = output.replace(/`([^`]+)`/g, '<code style="background:#f3f4f6;border-radius:4px;padding:2px 5px;font-size:90%;color:#111827;">$1</code>');
  output = output.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  output = output.replace(/\*([^*]+)\*/g, '<em>$1</em>');
  return output;
}

export function collectLocalImages(markdown, articlePath) {
  const images = [];
  const regex = /!\[[^\]]*]\(([^)]+)\)/g;
  for (const match of markdown.matchAll(regex)) {
    const src = match[1].trim();
    if (/^(https?:|data:)/i.test(src)) continue;
    images.push({
      original: src,
      absolute: resolveFromArticle(articlePath, src),
    });
  }
  return images;
}

export async function buildImageMap(markdown, articlePath, resolver) {
  const map = new Map();
  for (const image of collectLocalImages(markdown, articlePath)) {
    if (map.has(image.original)) continue;
    map.set(image.original, await resolver(image));
  }
  return map;
}

export async function renderMarkdown(markdown, options = {}) {
  const articlePath = options.articlePath;
  const imageResolver =
    options.imageResolver ??
    (async (image) => {
      if (image.absolute && fs.existsSync(image.absolute)) return toFileUrl(image.absolute);
      return image.original;
    });

  const imageMap = await buildImageMap(markdown, articlePath, imageResolver);
  const context = { imageMap };
  const lines = markdown.replace(/\r\n/g, '\n').split('\n');
  const html = [];

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (!line.trim()) continue;

    const fence = line.match(/^```(.*)$/);
    if (fence) {
      const lang = fence[1].trim();
      const code = [];
      i += 1;
      while (i < lines.length && !/^```/.test(lines[i])) {
        code.push(lines[i]);
        i += 1;
      }
      const langLabel = lang ? `<div style="font-size:12px;color:${COLORS.muted};margin-bottom:8px;">${escapeHtml(lang)}</div>` : '';
      html.push(
        `<section style="background:${COLORS.codeBg};border:1px solid ${COLORS.border};border-radius:8px;padding:14px 16px;margin:18px 0;overflow:auto;">${langLabel}<pre style="margin:0;white-space:pre-wrap;word-break:break-word;font-size:13px;line-height:1.7;color:#111827;"><code>${escapeHtml(code.join('\n'))}</code></pre></section>`,
      );
      continue;
    }

    const heading = line.match(/^(#{1,6})\s+(.+)$/);
    if (heading) {
      const level = heading[1].length;
      const content = renderInline(heading[2].trim(), context);
      if (level === 1) {
        html.push(`<h1 style="font-size:26px;line-height:1.35;font-weight:800;color:#111827;margin:28px 0 18px;">${content}</h1>`);
      } else if (level === 2) {
        html.push(`<h2 style="font-size:21px;line-height:1.45;font-weight:750;color:#111827;margin:30px 0 14px;padding-left:10px;border-left:4px solid ${COLORS.accent};">${content}</h2>`);
      } else {
        html.push(`<h3 style="font-size:17px;line-height:1.55;font-weight:700;color:#111827;margin:24px 0 12px;">${content}</h3>`);
      }
      continue;
    }

    if (/^>\s?/.test(line)) {
      const quote = [];
      while (i < lines.length && /^>\s?/.test(lines[i])) {
        quote.push(lines[i].replace(/^>\s?/, ''));
        i += 1;
      }
      i -= 1;
      html.push(
        `<blockquote style="margin:18px 0;padding:12px 16px;background:${COLORS.quoteBg};border-left:4px solid #94a3b8;color:#475569;border-radius:6px;">${quote.map((item) => `<p style="margin:6px 0;line-height:1.8;">${renderInline(item, context)}</p>`).join('')}</blockquote>`,
      );
      continue;
    }

    if (/^[-*+]\s+/.test(line) || /^\d+\.\s+/.test(line)) {
      const ordered = /^\d+\.\s+/.test(line);
      const items = [];
      const regex = ordered ? /^\d+\.\s+/ : /^[-*+]\s+/;
      while (i < lines.length && regex.test(lines[i])) {
        items.push(lines[i].replace(regex, '').trim());
        i += 1;
      }
      i -= 1;
      const tag = ordered ? 'ol' : 'ul';
      html.push(
        `<${tag} style="margin:14px 0 18px;padding-left:22px;color:${COLORS.text};line-height:1.85;">${items.map((item) => `<li style="margin:4px 0;">${renderInline(item, context)}</li>`).join('')}</${tag}>`,
      );
      continue;
    }

    if (line.includes('|') && i + 1 < lines.length && isTableSeparator(lines[i + 1])) {
      const headers = splitTableRow(line);
      i += 2;
      const rows = [];
      while (i < lines.length && lines[i].includes('|') && lines[i].trim()) {
        rows.push(splitTableRow(lines[i]));
        i += 1;
      }
      i -= 1;
      const headHtml = headers
        .map((cell) => `<th style="border:1px solid ${COLORS.border};background:#f8fafc;padding:9px 10px;text-align:left;font-weight:700;">${renderInline(cell, context)}</th>`)
        .join('');
      const bodyHtml = rows
        .map((row) => `<tr>${row.map((cell) => `<td style="border:1px solid ${COLORS.border};padding:9px 10px;vertical-align:top;">${renderInline(cell, context)}</td>`).join('')}</tr>`)
        .join('');
      html.push(`<section style="overflow-x:auto;margin:18px 0;"><table style="border-collapse:collapse;min-width:100%;font-size:14px;line-height:1.7;color:${COLORS.text};"><thead><tr>${headHtml}</tr></thead><tbody>${bodyHtml}</tbody></table></section>`);
      continue;
    }

    const paragraph = [line.trim()];
    while (i + 1 < lines.length && !isBlockStart(lines[i + 1])) {
      paragraph.push(lines[i + 1].trim());
      i += 1;
    }
    html.push(`<p style="font-size:16px;line-height:1.9;color:${COLORS.text};margin:14px 0;">${renderInline(paragraph.join(' '), context)}</p>`);
  }

  return html.join('\n');
}

export function wrapPreviewHtml({ title, content }) {
  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(title)}</title>
  <style>
    body { margin: 0; background: #f3f4f6; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    main { max-width: 677px; margin: 0 auto; min-height: 100vh; background: #fff; padding: 28px 22px 64px; box-sizing: border-box; }
  </style>
</head>
<body>
  <main>
${content}
  </main>
</body>
</html>
`;
}
