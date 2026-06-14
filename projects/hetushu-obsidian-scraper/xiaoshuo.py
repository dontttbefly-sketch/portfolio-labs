"""
和图书 (hetushu.com) 小说爬虫 v4
================================================================
修复：
  1. 卷文件夹名加零填充数字前缀（001_第一卷…）→ Obsidian 正确排序
  2. 重写 cn_to_int，支持"十一""一百二十三""三千五百""一万零三十"等
  3. 新增专项过滤"和图书"水印（含全角变体）

依赖安装（只需一次）：
    pip install playwright
    playwright install chromium

运行：
    cp .env.example .env
    python xiaoshuo.py
"""

import asyncio
import os
import re
from pathlib import Path
from datetime import datetime


# ══════════════════════════════════════════════════
# 配置区
# ══════════════════════════════════════════════════

def load_env_file(path: Path = Path(".env")) -> None:
    """加载本地 .env 配置；不会覆盖已经存在的系统环境变量。"""
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except ValueError:
        print(f"⚠️  环境变量 {name} 不是整数，已使用默认值 {default}")
        return default


def env_float(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, str(default)))
    except ValueError:
        print(f"⚠️  环境变量 {name} 不是数字，已使用默认值 {default}")
        return default


load_env_file()

OBSIDIAN_VAULT_PATH = os.getenv("OBSIDIAN_VAULT_PATH", str(Path.home() / "Obsidian"))
BOOK_TITLE = os.getenv("BOOK_TITLE", "凡人修仙传")
START_URL = os.getenv("START_URL", "https://www.hetushu.com/book/38/24721.html")
MAX_CHAPTERS = env_int("MAX_CHAPTERS", 9999)
DELAY_SECS = env_float("DELAY_SECS", 1.5)

# ══════════════════════════════════════════════════


# ──────────────────────────────────────────────────
# 【修复2】中文数字 → 整数（完整版）
# ──────────────────────────────────────────────────

_CN_NUM = {
    '零': 0, '〇': 0,
    '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
    '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
}
_CN_UNIT = {
    '十': 10,
    '百': 100,
    '千': 1000,
    '万': 10000,
}


def cn_to_int(s: str) -> int:
    """
    中文/阿拉伯混合数字 → 整数，支持到"万"级。
    示例：'十一'→11  '一百二十三'→123  '三千五百二十一'→3521
          '一万零三十'→10030  '2935'→2935
    """
    s = s.strip()
    # 纯阿拉伯数字
    if re.fullmatch(r'\d+', s):
        return int(s)

    # 只保留数字/单位字符
    filtered = [ch for ch in s if ch in _CN_NUM or ch in _CN_UNIT]
    s = ''.join(filtered)
    if not s:
        return 0

    total   = 0   # 万以上累计
    section = 0   # 当前万以下小节
    number  = 0   # 最近读到的 0‑9 数字

    for ch in s:
        if ch in _CN_NUM:
            number = _CN_NUM[ch]
        elif ch in _CN_UNIT:
            unit = _CN_UNIT[ch]
            if unit == 10000:
                section += number
                total   += section * unit
                section  = 0
                number   = 0
            else:
                # "十"开头省略"一"时 number==0，按 1 处理
                section += (number if number != 0 else 1) * unit
                number   = 0

    total += section + number
    return total


# ──────────────────────────────────────────────────
# 【修复3】水印清洗（全角URL + 和图书专项）
# ──────────────────────────────────────────────────

def fullwidth_to_ascii(text: str) -> str:
    """全角字符 → 半角，便于正则识别混淆 URL。"""
    result = []
    for ch in text:
        code = ord(ch)
        if 0xFF01 <= code <= 0xFF5E:
            result.append(chr(code - 0xFEE0))
        elif code == 0x3000:
            result.append(' ')
        else:
            result.append(ch)
    return ''.join(result)


# hetushu / hetubook 域名水印
_WATERMARK_DOMAIN_RE = re.compile(
    r'(?i)(?:https?://)?(?:www\.|m\.)*'
    r'h\s*e\s*t\s*u\s*(?:s\s*h\s*u|b\s*o\s*o\s*k)'
    r'[^\s\u4e00-\u9fff]*',
    re.UNICODE,
)

# 残留协议 / 顶级域名片段
_LEFTOVER_URL_RE = re.compile(
    r'(?i)(?:https?://\S*|(?:\.[a-z]{2,6}){1,3}\b)',
    re.UNICODE,
)

# 【专项】"和图书" / "和-图-书" / 全角变体 / 中间夹杂空白的情况
_HETUBOOK_RE = re.compile(
    r'(?:'
    r'[和龢\uff08\uff09]?\s*[图圖]\s*[书書]'   # 和图书 / 图书 变体
    r'|h\s*e\s*t\s*u\s*b\s*o\s*o\s*k'           # hetubook（半角，已由上面转换）
    r'|和\s*图\s*书'                              # 半角带空格
    r')',
    re.UNICODE | re.IGNORECASE,
)


def clean_watermarks(text: str) -> str:
    """
    三层水印清洗：
      1. 全角→半角，匹配 hetushu/hetubook 域名
      2. 清理残留 URL 片段
      3. 专项去除"和图书"文字水印
    """
    t = fullwidth_to_ascii(text)
    t = _WATERMARK_DOMAIN_RE.sub('', t)
    t = _LEFTOVER_URL_RE.sub('', t)
    t = _HETUBOOK_RE.sub('', t)
    t = re.sub(r'[ \t]{2,}', ' ', t)
    return t.strip()


# ──────────────────────────────────────────────────
# 【修复1】标题解析 + 带数字前缀的卷文件夹名
# ──────────────────────────────────────────────────

# 提取"第X卷"中的 X（中文或阿拉伯）
_VOL_NUM_RE  = re.compile(r'第([零〇一二两三四五六七八九十百千万\d]+)卷')
# 提取"第X章"中的 X
_CHAP_NUM_RE = re.compile(r'第([零〇一二两三四五六七八九十百千万\d]+)章')


def parse_title(full_title: str) -> tuple[str, str, int, int]:
    """
    解析完整标题字符串。
    返回 (vol_name, chap_name, vol_num, chap_num)

    示例：
      "第一卷 七玄门风云 第一章 山边小村"
      → ("第一卷 七玄门风云", "第一章 山边小村", 1, 1)
    """
    full_title = full_title.strip()

    vol_m  = _VOL_NUM_RE.search(full_title)
    chap_m = _CHAP_NUM_RE.search(full_title)

    # 卷名：从"第X卷"起到"第X章"前
    if vol_m and chap_m:
        vol_name = full_title[vol_m.start():chap_m.start()].strip()
    elif vol_m:
        vol_name = full_title[vol_m.start():].strip()
    else:
        vol_name = ""

    vol_num = cn_to_int(vol_m.group(1)) if vol_m else 0

    # 章名：从"第X章"到结尾
    if chap_m:
        chap_name = full_title[chap_m.start():].strip()
        chap_num  = cn_to_int(chap_m.group(1))
    else:
        chap_name = full_title
        chap_num  = 0

    return vol_name, chap_name, vol_num, chap_num


def vol_folder_name(vol_num: int, vol_name: str) -> str:
    """
    生成带零填充数字前缀的卷文件夹名，确保 Obsidian/Finder 按序排列。
    示例：vol_num=1, vol_name="第一卷 七玄门风云" → "001_第一卷 七玄门风云"
    """
    return f"{vol_num:03d}_{safe_name(vol_name)}"


# ──────────────────────────────────────────────────
# 工具：文件名安全化
# ──────────────────────────────────────────────────

def safe_name(name: str) -> str:
    """去除文件名/夹名中不合法的字符（兼容 iCloud 同步）。"""
    return re.sub(r'[\\/:*?"<>|]', '_', name).strip()


# ──────────────────────────────────────────────────
# 写入单章 Markdown 文件
# ──────────────────────────────────────────────────

def write_chapter_md(
    book_dir: Path,
    vol_name: str,
    vol_num: int,
    chap_name: str,
    chap_num: int,
    content: str,
    source_url: str,
) -> tuple[Path, str]:
    """
    将单章写成 Obsidian Markdown 文件。
    返回 (绝对路径, 相对于 book_dir 的路径字符串)
    """
    # 【修复1】卷文件夹带序号前缀
    if vol_name:
        chap_dir = book_dir / vol_folder_name(vol_num, vol_name)
    else:
        chap_dir = book_dir
    chap_dir.mkdir(parents=True, exist_ok=True)

    # 文件名：第0001章 山边小村.md
    chap_title_only = re.sub(
        r'^第[零〇一二两三四五六七八九十百千万\d]+章\s*', '', chap_name
    ).strip()
    filename = f"第{chap_num:04d}章 {safe_name(chap_title_only)}.md"
    filepath = chap_dir / filename

    # YAML frontmatter
    frontmatter = (
        "---\n"
        f'title: "{chap_name}"\n'
        f'book: "{BOOK_TITLE}"\n'
        f'volume: "{vol_name}"\n'
        f"vol_num: {vol_num}\n"
        f"chapter: {chap_num}\n"
        f'source: "{source_url}"\n'
        f"date_scraped: {datetime.now().strftime('%Y-%m-%d')}\n"
        "tags:\n"
        "  - 小说\n"
        f"  - {BOOK_TITLE}\n"
        "---\n"
    )

    # 正文：首行两个全角空格缩进，段落间空行
    paragraphs = ["\u3000\u3000" + p.strip() for p in content.split("\n\n") if p.strip()]
    body = "\n\n".join(paragraphs)

    filepath.write_text(f"{frontmatter}\n# {chap_name}\n\n{body}\n", encoding="utf-8")

    return filepath, str(filepath.relative_to(book_dir))


# ──────────────────────────────────────────────────
# 更新总目录 00_目录.md
# ──────────────────────────────────────────────────

def update_index(book_dir: Path, entries: list[dict]):
    """生成/覆盖总目录文件。"""
    lines = [
        f"# 《{BOOK_TITLE}》目录\n",
        f"> 共收录 **{len(entries)}** 章　"
        f"最后更新：{datetime.now().strftime('%Y-%m-%d %H:%M')}\n",
        "```dataview\n"
        f'TABLE vol_num AS 卷序, chapter AS 章节号, title AS 章节名\n'
        f'FROM "{safe_name(BOOK_TITLE)}"\n'
        "WHERE chapter > 0\n"
        "SORT vol_num ASC, chapter ASC\n"
        "```\n",
        "---\n",
    ]

    current_vol = None
    for e in entries:
        vol = e["vol_name"]
        if vol != current_vol:
            header = vol if vol else "正文"
            lines.append(f"\n## {header}\n")
            current_vol = vol

        # Obsidian wiki 链接：[[卷文件夹/文件名|显示名]]
        link_target = e["rel_path"].replace("\\", "/").removesuffix(".md")
        chap_title_only = re.sub(
            r'^第[零〇一二两三四五六七八九十百千万\d]+章\s*', '', e["chap_name"]
        ).strip()
        display = f"第{e['chap_num']:04d}章 {chap_title_only}"
        lines.append(f"- [[{link_target}|{display}]]")

    (book_dir / "00_目录.md").write_text("\n".join(lines), encoding="utf-8")


# ──────────────────────────────────────────────────
# Playwright：抓取单章
# ──────────────────────────────────────────────────

async def scrape_chapter(page, url: str) -> tuple[str, str, str | None]:
    await page.goto(url, wait_until="networkidle", timeout=30000)
    await page.wait_for_selector("#content", timeout=15000)

    # 等待 JS 乱序还原完成
    for _ in range(40):
        visible = await page.evaluate(
            "() => [...document.querySelectorAll('#content > div')]"
            "      .filter(el => el.offsetParent !== null).length"
        )
        if visible > 3:
            break
        await asyncio.sleep(0.3)

    # 标题：从正文 <h2> 拼接
    h2_texts = await page.evaluate(
        "() => [...document.querySelectorAll('#content h2')]"
        "      .map(el => el.innerText.trim()).filter(Boolean)"
    )
    full_title = " ".join(h2_texts) if h2_texts else await page.eval_on_selector(
        "#ctitle .title", "el => el.innerText.trim()"
    )

    # 正文段落
    paragraphs = await page.evaluate("""
        () => {
            const content = document.querySelector('#content');
            if (!content) return [];
            const result = [];
            for (const child of content.childNodes) {
                if (child.nodeType !== 1 || child.tagName !== 'DIV') continue;
                if (child.offsetParent === null) continue;
                const cs = window.getComputedStyle(child);
                if (cs.display === 'none' || cs.visibility === 'hidden') continue;
                const clone = child.cloneNode(true);
                // 移除所有已知水印标签（包含"和图书"的 <tt>）
                clone.querySelectorAll(
                    'kbd, tt, samp, acronym, span[style], .mask, .mask2'
                ).forEach(el => el.remove());
                const text = clone.innerText.trim();
                if (text) result.push(text);
            }
            return result;
        }
    """)

    cleaned = [clean_watermarks(p) for p in paragraphs]
    cleaned = [p for p in cleaned if p]
    content_text = "\n\n".join(cleaned)

    # 下一章链接
    next_url = await page.evaluate("""
        () => {
            const a = document.querySelector('#next');
            const href = a ? a.href : null;
            return (href && !href.endsWith('#') && !href.endsWith('/')) ? href : null;
        }
    """)

    return full_title, content_text, next_url


# ──────────────────────────────────────────────────
# 主流程
# ──────────────────────────────────────────────────

async def main():
    try:
        from playwright.async_api import async_playwright
    except ImportError:
        print("❌ 请先执行：pip install playwright && playwright install chromium")
        return

    vault = Path(OBSIDIAN_VAULT_PATH).expanduser()
    if not vault.exists():
        print(f"❌ Vault 路径不存在：{vault}")
        print("   请复制 .env.example 为 .env，并把 OBSIDIAN_VAULT_PATH 改成你的 Obsidian 笔记库路径。")
        return

    book_dir = vault / safe_name(BOOK_TITLE)
    book_dir.mkdir(parents=True, exist_ok=True)

    print(f"📖  书名：{BOOK_TITLE}")
    print(f"🗂   输出：{book_dir}")
    print("─" * 62)

    entries: list[dict] = []
    chapter_count = 0
    current_url = START_URL

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            args=["--no-sandbox", "--disable-setuid-sandbox"],
        )
        ctx = await browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
            locale="zh-CN",
        )
        page = await ctx.new_page()

        while current_url and chapter_count < MAX_CHAPTERS:
            try:
                print(f"[{chapter_count + 1:>4}] {current_url}")

                full_title, content, next_url = await scrape_chapter(page, current_url)
                vol_name, chap_name, vol_num, chap_num = parse_title(full_title)

                filepath, rel_path = write_chapter_md(
                    book_dir, vol_name, vol_num,
                    chap_name, chap_num, content, current_url,
                )

                entries.append({
                    "vol_name":  vol_name,
                    "vol_num":   vol_num,
                    "chap_name": chap_name,
                    "chap_num":  chap_num,
                    "rel_path":  rel_path,
                })
                update_index(book_dir, entries)

                print(f"       ✓  卷{vol_num:03d} · 第{chap_num:04d}章  [{len(content):,} 字]")
                print(f"          {filepath.relative_to(vault)}")

                chapter_count += 1
                current_url = next_url
                if current_url:
                    await asyncio.sleep(DELAY_SECS)

            except Exception as exc:
                print(f"       ✗  失败：{exc}  → 5 秒后重试")
                await asyncio.sleep(5)
                try:
                    full_title, content, next_url = await scrape_chapter(page, current_url)
                    vol_name, chap_name, vol_num, chap_num = parse_title(full_title)
                    filepath, rel_path = write_chapter_md(
                        book_dir, vol_name, vol_num,
                        chap_name, chap_num, content, current_url,
                    )
                    entries.append({
                        "vol_name": vol_name, "vol_num": vol_num,
                        "chap_name": chap_name, "chap_num": chap_num,
                        "rel_path": rel_path,
                    })
                    update_index(book_dir, entries)
                    chapter_count += 1
                    current_url = next_url
                except Exception as exc2:
                    print(f"          重试仍失败，终止：{exc2}")
                    break

        await browser.close()

    print("─" * 62)
    print(f"✅  完成！共爬取 {chapter_count} 章，文件位于：{book_dir}")


if __name__ == "__main__":
    asyncio.run(main())
