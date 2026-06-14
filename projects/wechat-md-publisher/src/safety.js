const SENSITIVE_PATTERNS = [
  { name: 'GitHub token', regex: /\b(?:gho|ghp|github_pat)_[A-Za-z0-9_]{20,}\b/g },
  { name: 'OpenAI style token', regex: /\bsk-[A-Za-z0-9_-]{20,}\b/g },
  { name: 'Slack token', regex: /\bxox[baprs]-[A-Za-z0-9-]{20,}\b/g },
  { name: 'Feishu webhook', regex: /open-apis\/bot\/v2\/hook\/[A-Za-z0-9_-]{8,}/g },
  { name: 'Feishu app id', regex: /\bcli_[A-Za-z0-9]{8,}\b/g },
  { name: 'Feishu chat id', regex: /\boc_[A-Za-z0-9]{8,}\b/g },
  { name: 'Feishu open id', regex: /\bou_[A-Za-z0-9]{8,}\b/g },
  { name: 'Bitable table id', regex: /\btbl[A-Za-z0-9]{8,}\b/g },
  { name: 'Bitable view id', regex: /\bvew[A-Za-z0-9]{8,}\b/g },
  { name: 'Access token literal', regex: /\baccess_token["'\s:=]+[A-Za-z0-9._-]{12,}/gi },
  { name: 'Secret assignment', regex: /\b(?:secret|appsecret|app_secret|WECHAT_APP_SECRET)["'\s:=]+[A-Za-z0-9._-]{12,}/gi },
];

function isPlaceholder(value) {
  return /x{4,}/i.test(value) || /<[^>]+>/.test(value) || /YOUR_|PLACEHOLDER/i.test(value);
}

export function scanSensitiveText(text) {
  const findings = [];

  for (const pattern of SENSITIVE_PATTERNS) {
    for (const match of text.matchAll(pattern.regex)) {
      const value = match[0];
      if (isPlaceholder(value)) continue;
      findings.push({
        type: pattern.name,
        value,
        index: match.index ?? 0,
      });
    }
  }

  return findings;
}

export function maskSensitive(value) {
  if (!value) return value;
  return String(value)
    .replace(/access_token=([^&\s]+)/g, 'access_token=<ACCESS_TOKEN>')
    .replace(/secret=([^&\s]+)/g, 'secret=<APP_SECRET>')
    .replace(/\b[A-Za-z0-9_-]{24,}\b/g, (match) => `${match.slice(0, 4)}...${match.slice(-4)}`);
}
