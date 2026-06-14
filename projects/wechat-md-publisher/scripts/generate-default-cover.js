import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const WIDTH = 900;
const HEIGHT = 383;

const FONT = {
  A: ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  B: ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
  C: ['01111', '10000', '10000', '10000', '10000', '10000', '01111'],
  D: ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  E: ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  G: ['01111', '10000', '10000', '10111', '10001', '10001', '01111'],
  I: ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
  N: ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
  O: ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
  R: ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
  V: ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
  Y: ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
  ' ': ['000', '000', '000', '000', '000', '000', '000'],
};

const pixels = Buffer.alloc(WIDTH * HEIGHT * 4);

function setPixel(x, y, rgba) {
  if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT) return;
  const index = (y * WIDTH + x) * 4;
  pixels[index] = rgba[0];
  pixels[index + 1] = rgba[1];
  pixels[index + 2] = rgba[2];
  pixels[index + 3] = rgba[3];
}

function fillRect(x, y, w, h, rgba) {
  for (let yy = y; yy < y + h; yy += 1) {
    for (let xx = x; xx < x + w; xx += 1) setPixel(xx, yy, rgba);
  }
}

function drawText(text, x, y, scale, rgba) {
  let cursor = x;
  for (const char of text.toUpperCase()) {
    const glyph = FONT[char] || FONT[' '];
    for (let row = 0; row < glyph.length; row += 1) {
      for (let col = 0; col < glyph[row].length; col += 1) {
        if (glyph[row][col] === '1') fillRect(cursor + col * scale, y + row * scale, scale, scale, rgba);
      }
    }
    cursor += (glyph[0].length + 1) * scale;
  }
}

function drawCircle(cx, cy, radius, rgba) {
  const r2 = radius * radius;
  for (let y = cy - radius; y <= cy + radius; y += 1) {
    for (let x = cx - radius; x <= cx + radius; x += 1) {
      const dx = x - cx;
      const dy = y - cy;
      if (dx * dx + dy * dy <= r2) setPixel(x, y, rgba);
    }
  }
}

function crc32(buffer) {
  let crc = ~0;
  for (const byte of buffer) {
    crc ^= byte;
    for (let k = 0; k < 8; k += 1) crc = crc & 1 ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1;
  }
  return ~crc >>> 0;
}

function chunk(type, data) {
  const typeBuffer = Buffer.from(type);
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuffer, data])));
  return Buffer.concat([length, typeBuffer, data, crc]);
}

function pngBuffer() {
  const raw = Buffer.alloc((WIDTH * 4 + 1) * HEIGHT);
  for (let y = 0; y < HEIGHT; y += 1) {
    raw[y * (WIDTH * 4 + 1)] = 0;
    pixels.copy(raw, y * (WIDTH * 4 + 1) + 1, y * WIDTH * 4, (y + 1) * WIDTH * 4);
  }

  const header = Buffer.alloc(13);
  header.writeUInt32BE(WIDTH, 0);
  header.writeUInt32BE(HEIGHT, 4);
  header[8] = 8;
  header[9] = 6;
  header[10] = 0;
  header[11] = 0;
  header[12] = 0;

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', header),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

for (let y = 0; y < HEIGHT; y += 1) {
  for (let x = 0; x < WIDTH; x += 1) {
    const t = x / WIDTH;
    const u = y / HEIGHT;
    setPixel(x, y, [
      Math.round(20 + 40 * t),
      Math.round(28 + 44 * u),
      Math.round(42 + 70 * t),
      255,
    ]);
  }
}

drawCircle(720, 92, 130, [69, 211, 255, 52]);
drawCircle(120, 310, 170, [255, 209, 102, 42]);
fillRect(72, 72, 756, 239, [255, 255, 255, 26]);
fillRect(78, 78, 744, 227, [15, 23, 42, 160]);
fillRect(112, 106, 96, 8, [96, 165, 250, 255]);
drawText('VIBE CODING', 112, 146, 13, [248, 250, 252, 255]);
drawText('DIARY', 114, 244, 7, [147, 197, 253, 255]);
drawText('CODEX WORKFLOW NOTES', 318, 252, 5, [226, 232, 240, 255]);

const outPath = path.resolve(process.cwd(), 'assets/default-cover.png');
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, pngBuffer());
console.log(`Generated ${outPath}`);
