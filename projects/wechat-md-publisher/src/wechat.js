import fs from 'node:fs';
import path from 'node:path';
import { readCache, updateCache, writeCache } from './cache.js';
import { hashFile } from './hash.js';
import { maskSensitive } from './safety.js';

const API_BASE = 'https://api.weixin.qq.com';

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`缺少环境变量：${name}。请复制 .env.example 为 .env 后填写。`);
  return value;
}

function assertWechatOk(json, action) {
  if (json && json.errcode && json.errcode !== 0) {
    throw new Error(`${action}失败：${json.errcode} ${json.errmsg || ''}`);
  }
}

async function fetchJson(url, options, action) {
  const res = await fetch(url, options);
  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`${action}失败：HTTP ${res.status} ${maskSensitive(JSON.stringify(json || {}))}`);
  }
  assertWechatOk(json, action);
  return json;
}

function contentTypeFor(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.jpg' || ext === '.jpeg') return 'image/jpeg';
  if (ext === '.png') return 'image/png';
  if (ext === '.gif') return 'image/gif';
  if (ext === '.webp') return 'image/webp';
  return 'application/octet-stream';
}

async function postMultipart(url, filePath, action) {
  const boundary = `----wechat-md-${Date.now().toString(16)}`;
  const filename = path.basename(filePath);
  const fileBuffer = fs.readFileSync(filePath);
  const header = Buffer.from(
    `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="media"; filename="${filename}"\r\n` +
      `Content-Type: ${contentTypeFor(filePath)}\r\n\r\n`,
  );
  const footer = Buffer.from(`\r\n--${boundary}--\r\n`);

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': `multipart/form-data; boundary=${boundary}`,
    },
    body: Buffer.concat([header, fileBuffer, footer]),
  });
  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`${action}失败：HTTP ${res.status} ${maskSensitive(JSON.stringify(json || {}))}`);
  }
  assertWechatOk(json, action);
  return json;
}

export async function getAccessToken() {
  const appId = requiredEnv('WECHAT_APP_ID');
  const appSecret = requiredEnv('WECHAT_APP_SECRET');
  const cached = readCache('access-token.json');
  const now = Date.now();

  if (cached?.app_id === appId && cached?.access_token && cached?.expires_at > now + 5 * 60 * 1000) {
    return cached.access_token;
  }

  const url =
    `${API_BASE}/cgi-bin/token?grant_type=client_credential` +
    `&appid=${encodeURIComponent(appId)}` +
    `&secret=${encodeURIComponent(appSecret)}`;
  const json = await fetchJson(url, { method: 'GET' }, '获取 access_token');
  const expiresIn = Number(json.expires_in || 7200);
  writeCache('access-token.json', {
    app_id: appId,
    access_token: json.access_token,
    expires_at: now + Math.max(0, expiresIn - 300) * 1000,
  });
  return json.access_token;
}

export async function uploadArticleImage(filePath, accessToken) {
  const hash = hashFile(filePath);
  const cache = readCache('uploaded-images.json', {});
  if (cache[hash]?.url) return cache[hash].url;

  const url = `${API_BASE}/cgi-bin/media/uploadimg?access_token=${encodeURIComponent(accessToken)}`;
  const json = await postMultipart(url, filePath, `上传正文图片 ${path.basename(filePath)}`);
  if (!json.url) throw new Error(`上传正文图片失败：微信未返回 url`);

  updateCache('uploaded-images.json', (current) => ({
    ...current,
    [hash]: {
      url: json.url,
      file: path.basename(filePath),
      uploaded_at: new Date().toISOString(),
    },
  }));
  return json.url;
}

export async function uploadCover(filePath, accessToken) {
  const hash = hashFile(filePath);
  const cache = readCache('uploaded-covers.json', {});
  if (cache[hash]?.thumb_media_id) return cache[hash].thumb_media_id;

  const url = `${API_BASE}/cgi-bin/material/add_material?access_token=${encodeURIComponent(accessToken)}&type=thumb`;
  const json = await postMultipart(url, filePath, `上传封面 ${path.basename(filePath)}`);
  const thumbMediaId = json.media_id;
  if (!thumbMediaId) throw new Error(`上传封面失败：微信未返回 media_id`);

  updateCache('uploaded-covers.json', (current) => ({
    ...current,
    [hash]: {
      thumb_media_id: thumbMediaId,
      file: path.basename(filePath),
      uploaded_at: new Date().toISOString(),
    },
  }));
  return thumbMediaId;
}

export async function addDraft(article, html, thumbMediaId, accessToken) {
  const payload = {
    articles: [
      {
        title: article.meta.title,
        author: article.meta.author,
        digest: article.meta.digest,
        content: html,
        content_source_url: article.meta.sourceUrl || '',
        thumb_media_id: thumbMediaId,
        show_cover_pic: article.meta.showCoverPic ? 1 : 0,
        need_open_comment: 0,
        only_fans_can_comment: 0,
      },
    ],
  };

  const url = `${API_BASE}/cgi-bin/draft/add?access_token=${encodeURIComponent(accessToken)}`;
  const json = await fetchJson(
    url,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify(payload),
    },
    '新增草稿',
  );

  if (!json.media_id) throw new Error('新增草稿失败：微信未返回 media_id');
  return json.media_id;
}
