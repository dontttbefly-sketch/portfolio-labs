# 《凡人修仙传》爬虫项目完全教学文档

> **适合读者**：懂 Python 基础语法（变量、函数、if/for、类），但从未做过实际项目的初学者。
> 本文档会带你逐字逐句看懂这个真实的工程级爬虫脚本，并解释每一个"为什么这样写"。

---

## 📋 目录

1. [这个项目要做什么？](#1-这个项目要做什么)
2. [运行之前需要准备什么？](#2-运行之前需要准备什么)
3. [代码整体地图](#3-代码整体地图)
4. [第一部分：配置区](#4-第一部分配置区)
5. [第二部分：文字清洗](#5-第二部分文字清洗)
6. [第三部分：标题解析](#6-第三部分标题解析)
7. [第四部分：文件名安全化](#7-第四部分文件名安全化)
8. [第五部分：写入 Markdown 文件](#8-第五部分写入-markdown-文件)
9. [第六部分：更新总目录](#9-第六部分更新总目录)
10. [第七部分：Playwright 抓取单章](#10-第七部分playwright-抓取单章)
11. [第八部分：主流程 main()](#11-第八部分主流程-main)
12. [数据流动全貌](#12-数据流动全貌)
13. [常见问题与排错指南](#13-常见问题与排错指南)
14. [进阶思考：如果让你改造这个项目](#14-进阶思考如果让你改造这个项目)

---

## 1. 这个项目要做什么？

### 1.1 最终效果

运行这个脚本后，你的 Obsidian 笔记库里会出现这样的文件夹结构：

```
📁 python/                          ← 你的 Obsidian Vault（笔记库根目录）
└── 📁 凡人修仙传/
    ├── 📄 00_目录.md               ← 全书目录，点击可跳转任意章节
    ├── 📁 第一卷 七玄门风云/
    │   ├── 📄 第0001章 山边小村.md
    │   ├── 📄 第0002章 青牛镇.md
    │   └── ...
    ├── 📁 第二卷 .../
    │   └── ...
    └── ...
```

每个章节文件内容长这样：

```markdown
---
title: "第一章 山边小村"
book: "凡人修仙传"
volume: "第一卷 七玄门风云"
chapter: 1
source: "https://www.hetushu.com/..."
date_scraped: 2024-01-15
tags:
  - 小说
  - 凡人修仙传
---

# 第一章 山边小村

　　韩立无奈地看着...（正文内容）
```

### 1.2 技术挑战是什么？

你可能想问：直接复制粘贴不就行了？为什么要写这么复杂的程序？

问题在于：
1. **全书有 2000+ 章**，手工复制不现实
2. **网站用了反爬措施**：段落故意被 JS 打乱顺序，还插入了隐藏的水印文字
3. **需要自动翻页**：每章有"下一章"链接，要自动跟着走

所以这个脚本用了 **Playwright** —— 一个能控制真实浏览器的工具，让浏览器完整运行 JS 后再读取内容，绕过了段落乱序的问题。

---

## 2. 运行之前需要准备什么？

### 2.1 安装依赖

打开终端（Mac 用 Terminal，Windows 用 PowerShell），依次运行：

```bash
pip install playwright
playwright install chromium
```

**为什么需要 Playwright？**
普通的 `requests` 库只能下载 HTML 源码，但这个网站的正文是靠 JavaScript 动态生成的。Playwright 会启动一个真实的 Chrome 浏览器（Chromium），让 JS 完整运行后再读内容。

### 2.2 修改配置

打开脚本，找到"配置区"，修改这几行：

```python
OBSIDIAN_VAULT_PATH = "~/Obsidian"  # 改成你自己的 Vault 路径
BOOK_TITLE   = "凡人修仙传"                    # 书名（用于文件夹名）
START_URL    = "https://..."                    # 第一章的网址
MAX_CHAPTERS = 9999                             # 最多爬多少章
DELAY_SECS   = 1.5                              # 每章之间等待几秒
```

---

## 3. 代码整体地图

在深入细节之前，先建立一个整体认知。这个脚本由**8个功能模块**组成：

```
hetushu_scraper.py
│
├── 📦 导入区（import）
│   └── asyncio, re, Path, datetime
│
├── ⚙️ 配置区（全局变量）
│   └── VAULT路径、书名、起始URL等
│
├── 🧹 工具函数1：文字清洗
│   ├── fullwidth_to_ascii()   全角→半角
│   └── clean_watermarks()     去除水印
│
├── 📖 工具函数2：标题解析
│   ├── cn_to_int()            中文数字→整数
│   └── parse_title()          解析"第x卷 第x章"
│
├── 🗂️ 工具函数3：文件系统
│   └── safe_name()            文件名安全化
│
├── 💾 工具函数4：写文件
│   └── write_chapter_md()     写单章Markdown
│
├── 📋 工具函数5：目录管理
│   └── update_index()         更新总目录文件
│
├── 🌐 核心函数：网络爬取
│   └── scrape_chapter()       用Playwright抓一章内容
│
└── 🚀 主流程
    └── main()                 串联所有模块，循环爬取
```

**程序执行顺序**：`main()` → 循环调用 `scrape_chapter()` → 解析 → 写文件 → 更新目录 → 跳下一章

---

## 4. 第一部分：配置区

```python
import asyncio
import re
from pathlib import Path
from datetime import datetime
```

### 4.1 为什么导入这些？

| 模块 | 用途 |
|------|------|
| `asyncio` | 异步编程框架，Playwright 必须用它 |
| `re` | 正则表达式，用于复杂的文字匹配和替换 |
| `pathlib.Path` | 现代的文件路径操作（比老式字符串拼接更安全） |
| `datetime` | 获取当前日期，写到文件的 frontmatter 里 |

**什么是异步（asyncio）？**

想象你在餐厅点菜。同步方式：你点完菜，站在原地等，厨房做好了你再走。异步方式：你点完菜，去旁边坐着刷手机，厨房好了叫你。

Playwright 控制浏览器时，浏览器需要时间加载页面（网络请求、JS 运行）。如果用同步方式，Python 就会傻等；用异步，Python 可以去做别的事（虽然这个脚本没并发，但 Playwright 的 API 设计要求用 async）。

### 4.2 配置变量

```python
OBSIDIAN_VAULT_PATH = os.getenv("OBSIDIAN_VAULT_PATH", str(Path.home() / "Obsidian"))
BOOK_TITLE   = "凡人修仙传"
START_URL    = "https://www.hetushu.com/book/38/24721.html"
MAX_CHAPTERS = 9999
DELAY_SECS   = 1.5
```

**设计思路**：把所有"会变的参数"集中放在顶部，这是一个好习惯。以后想爬别的书，只改这几行就行，不用翻遍整个代码。

`DELAY_SECS = 1.5` 这行很重要！每章之间等待 1.5 秒，是对服务器的基本尊重，也能降低被封 IP 的风险。如果改成 0，短时间内发几千个请求，网站会封你。

---

## 5. 第二部分：文字清洗

这是整个脚本里技术含量最高的部分之一。我们要对付网站的**反爬水印**。

### 5.1 什么是"全角字符水印"？

网站会把水印 URL 藏在正文里，但用了全角字符，看起来像汉字，肉眼难辨：

```
正常URL：  hetushu.com
水印URL：  ｈｅｔｕｓｈｕ．ｃｏｍ   ← 看起来相似，但字符编码完全不同！
```

全角 `ｈ` 的 Unicode 编码是 `0xFF48`，而正常 `h` 是 `0x0068`，相差 `0xFEE0`。

### 5.2 `fullwidth_to_ascii()` — 全角转半角

```python
def fullwidth_to_ascii(text: str) -> str:
    """全角字母/数字/标点 → 半角，方便识别混淆的水印 URL。"""
    result = []
    for ch in text:
        code = ord(ch)
        if 0xFF01 <= code <= 0xFF5E:   # 全角可见 ASCII 的范围
            result.append(chr(code - 0xFEE0))
        elif code == 0x3000:            # 全角空格
            result.append(' ')
        else:
            result.append(ch)
    return ''.join(result)
```

**逐行解析**：

- `ord(ch)`：把字符转成 Unicode 编码数字。例如 `ord('A')` = 65，`ord('Ａ')` = 65313
- `0xFF01 <= code <= 0xFF5E`：这是全角可见字符的 Unicode 范围
- `chr(code - 0xFEE0)`：减去固定差值 `0xFEE0`（65248），就变回对应的半角字符
- `result = []` + `''.join(result)`：这是 Python 中拼接字符串的高效写法。如果用 `result += ch`，每次拼接都会创建新字符串，很慢。用列表收集再 `join`，效率高得多。

**小实验，你可以在 Python 里试试**：
```python
print(ord('ｈ'))           # 输出：65352 (0xFF48)
print(ord('h'))            # 输出：104   (0x68)
print(65352 - 65248)       # 输出：104   ✓ 刚好是 'h' 的编码
```

### 5.3 正则表达式水印匹配

```python
_WATERMARK_RE = re.compile(
    r'(?i)'
    r'(?:https?://)?'
    r'(?:www\.|m\.)*'
    r'h\s*e\s*t\s*u\s*(?:s\s*h\s*u|b\s*o\s*o\s*k)'
    r'[^\s\u4e00-\u9fff]*',
    re.UNICODE,
)
```

这段正则表达式是用来匹配 `hetushu` 或 `hetubook` 各种变体的，我们来拆解它：

| 部分 | 含义 |
|------|------|
| `(?i)` | 忽略大小写 |
| `(?:https?://)?` | 可选的 http:// 或 https://，`?` 表示出现0次或1次 |
| `(?:www\.|m\.)*` | 可选的 www. 或 m.（移动端），`*` 表示出现0次或多次 |
| `h\s*e\s*t\s*u` | 匹配 h、e、t、u，每个字母之间可以有任意空白 |
| `(?:s\s*h\s*u\|b\s*o\s*o\s*k)` | 匹配 `shu` 或 `book`（两种域名变体） |
| `[^\s\u4e00-\u9fff]*` | 继续匹配非空白、非中文的字符（域名后缀） |

**为什么字母之间要 `\s*`（允许空白）？**

网站会故意在水印字母之间插入隐形空格，让正则难以匹配。比如 `h e t u s h u`，加了 `\s*` 就都能匹配到了。

### 5.4 `clean_watermarks()` — 综合清洗

```python
def clean_watermarks(text: str) -> str:
    t = fullwidth_to_ascii(text)    # 步骤1：全角→半角
    t = _WATERMARK_RE.sub('', t)   # 步骤2：删除水印URL
    t = _LEFTOVER_RE.sub('', t)    # 步骤3：删除残留URL
    t = re.sub(r'[ \t]{2,}', ' ', t)  # 步骤4：多余空格合并成一个
    return t.strip()                # 步骤5：去首尾空白
```

这是一个典型的**管道处理模式（Pipeline）**：把输入数据依次经过多道"过滤器"，每步都针对一个问题。你会在很多数据处理代码中见到这个模式。

---

## 6. 第三部分：标题解析

### 6.1 问题背景

网站上的章节标题是这样的字符串：

```
"第一卷 七玄门风云 第一章 山边小村"
```

我们需要把它拆解成：
- 卷名：`"第一卷 七玄门风云"`
- 章名：`"第一章 山边小村"`
- 章号：`1`（整数，用于文件排序）

### 6.2 `cn_to_int()` — 中文数字转整数

```python
_CN_DIGIT = {
    '零':0,'一':1,'二':2,'三':3,'四':4,
    '五':5,'六':6,'七':7,'八':8,'九':9,
    '十':10,'百':100,'千':1000,
}

def cn_to_int(s: str) -> int:
    if re.fullmatch(r'\d+', s):
        return int(s)       # 如果本来就是阿拉伯数字，直接转
    result, cur = 0, 0
    for ch in s:
        if ch.isdigit():
            cur = cur * 10 + int(ch)
        elif ch in _CN_DIGIT:
            val = _CN_DIGIT[ch]
            if val >= 10:                  # 是"十/百/千"这类"位值"
                cur = (cur or 1) * val     # 例如 "三百" → cur=3, val=100, cur=300
                if val >= 100:
                    result += cur          # 百以上就把 cur 并入 result
                    cur = 0
            else:                          # 是"一~九"这类"数值"
                cur = cur * 10 + val
    return result + cur
```

**举例追踪"三百零五"**：

| 字符 | val | cur | result | 说明 |
|------|-----|-----|--------|------|
| 三 | 3 | 3 | 0 | cur=3 |
| 百 | 100 | 300 | 300 | cur=(3)*100=300, >=100所以result+=300, cur=0 |
| 零 | 0 | 0 | 300 | cur=0*10+0=0 |
| 五 | 5 | 5 | 300 | cur=0*10+5=5 |
| 结束 | - | - | 305 | return 300+5=305 ✓ |

**`cur or 1` 这个写法是什么意思？**

当遇到"十"开头的数字时（如"十三"），cur 还是 0，`0 or 1` 返回 1，所以 `1 * 10 = 10`，然后加上后面的 3，得到 13。这是一个处理边界情况的小技巧。

### 6.3 `parse_title()` — 解析完整标题

```python
_VOL_FULL_RE  = re.compile(r'(第[零一二三四五六七八九十百千\d]+卷(?:\s*\S+)*)')
_CHAP_FULL_RE = re.compile(r'(第([零一二三四五六七八九十百千\d]+)章(?:\s*\S+)*)')

def parse_title(full_title: str) -> tuple[str, str, int]:
    full_title = full_title.strip()
    
    vol_m  = _VOL_FULL_RE.search(full_title)
    chap_m = _CHAP_FULL_RE.search(full_title)

    if vol_m and chap_m:
        vol_name = full_title[vol_m.start():chap_m.start()].strip()
    elif vol_m:
        vol_name = vol_m.group(1).strip()
    else:
        vol_name = ""

    if chap_m:
        chap_name = full_title[chap_m.start():].strip()
        chap_num  = cn_to_int(chap_m.group(2))
    else:
        chap_name = full_title
        chap_num  = 0

    return vol_name, chap_name, chap_num
```

**`re.search()` vs `re.match()`**：
- `match()` 只匹配字符串**开头**
- `search()` 在整个字符串里**搜索**，找到第一个匹配就返回

我们用 `search()` 因为标题里"第x卷"可能不在最开头。

**`.start()` 是什么？**

`match_object.start()` 返回匹配到的内容在原字符串中的起始位置（索引）。

例如 `"第一卷 七玄门风云 第一章 山边小村"` 中：
- `vol_m.start()` = 0（"第"在索引0）
- `chap_m.start()` = 9（"第一章"的"第"在索引9）
- `full_title[0:9]` = `"第一卷 七玄门风云 "` → strip 后得卷名

**返回值类型提示 `tuple[str, str, int]`**：

这是 Python 3.9+ 的类型注解（Type Hint），告诉其他程序员这个函数返回一个包含两个字符串和一个整数的元组。它不影响程序运行，只是提升代码可读性。

---

## 7. 第四部分：文件名安全化

```python
def safe_name(name: str) -> str:
    """去除文件名/文件夹名中不合法的字符。"""
    name = re.sub(r'[\\/:*?"<>|]', '_', name)
    return name.strip()
```

**为什么需要这个？**

不同操作系统对文件名有不同限制：
- Windows 禁止：`\ / : * ? " < > |`
- macOS 禁止：`/`（以及 iCloud 同步有额外限制）

小说标题里可能含有 `？`（问号）或 `：`（冒号），比如"第三章：大战？"。如果直接用作文件名会报错。

`re.sub(r'[...]', '_', name)` 把所有非法字符替换成下划线 `_`。方括号 `[...]` 在正则里表示"匹配其中任意一个字符"。

---

## 8. 第五部分：写入 Markdown 文件

```python
def write_chapter_md(
    book_dir: Path,
    vol_name: str,
    chap_name: str,
    chap_num: int,
    content: str,
    source_url: str,
) -> tuple[Path, str]:
```

### 8.1 确定文件保存位置

```python
if vol_name:
    chap_dir = book_dir / safe_name(vol_name)
else:
    chap_dir = book_dir
chap_dir.mkdir(parents=True, exist_ok=True)
```

**`Path` 对象的 `/` 运算符**：

这是 `pathlib` 的魔法。`book_dir / safe_name(vol_name)` 不是数学除法，而是路径拼接。比：
```python
book_dir / "第一卷 七玄门风云"
# 等价于老写法：
os.path.join(book_dir, "第一卷 七玄门风云")
```

`Path` 重载了 `/` 运算符，让路径拼接更直观。

**`mkdir(parents=True, exist_ok=True)`**：
- `parents=True`：如果中间的父目录不存在，一并创建
- `exist_ok=True`：如果目录已存在，不报错（默认会抛出异常）

### 8.2 生成文件名

```python
chap_title_only = re.sub(r'^第[零一二三四五六七八九十百千\d]+章\s*', '', chap_name).strip()
filename = f"第{chap_num:04d}章 {safe_name(chap_title_only)}.md"
```

**`^`** 在正则里表示"字符串开头"，所以只替换开头的"第x章"，不会误替换正文里的"第x章"。

**`:04d` 是什么格式化语法？**

这是 Python f-string 的格式说明符：
- `04` = 不足4位时用0补齐
- `d` = 整数

```python
f"第{1:04d}章"    # → "第0001章"
f"第{100:04d}章"  # → "第0100章"
f"第{1000:04d}章" # → "第1000章"
```

为什么要补零？因为文件系统排序是字母序，不补零的话：

```
第1章、第10章、第100章、第2章、第20章...  ← 错误顺序
第0001章、第0002章、...、第0010章、...    ← 正确顺序
```

### 8.3 YAML Frontmatter

```python
frontmatter = (
    f"---\n"
    f'title: "{chap_name}"\n'
    f'book: "{BOOK_TITLE}"\n'
    f'volume: "{vol_name}"\n'
    f"chapter: {chap_num}\n"
    f'source: "{source_url}"\n'
    f"date_scraped: {now}\n"
    f"tags:\n"
    f"  - 小说\n"
    f"  - {BOOK_TITLE}\n"
    f"---\n"
)
```

**YAML Frontmatter 是什么？**

Markdown 文件开头用 `---` 包裹的部分叫 frontmatter，是给工具读取的"元数据"。Obsidian 会解析它，让你可以用 Dataview 插件做数据库查询，比如"列出所有 chapter < 100 的章节"。

### 8.4 正文排版

```python
body_lines = []
for para in content.split("\n\n"):
    para = para.strip()
    if para:
        body_lines.append("\u3000\u3000" + para)
body = "\n\n".join(body_lines)
```

- `content.split("\n\n")`：以空行分割段落（之前在 `scrape_chapter` 里段落用 `"\n\n"` 连接）
- `"\u3000\u3000"`：两个全角空格（中文段落首行缩进2字符的习惯）
- `"\n\n".join(body_lines)`：段落之间再用空行连接，Markdown 里空行才是段落分隔

### 8.5 写入文件并返回相对路径

```python
filepath.write_text(md_content, encoding="utf-8")
rel = filepath.relative_to(book_dir)
return filepath, str(rel)
```

**为什么要返回相对路径？**

绝对路径依赖机器，在你的电脑上可能是 `~/Obsidian/...`，在别人电脑上就不对了。Obsidian 的 wiki 链接 `[[相对路径]]` 用相对路径，可以跨平台使用。

---

## 9. 第六部分：更新总目录

```python
def update_index(book_dir: Path, entries: list[dict]):
```

### 9.1 为什么每章后都立即更新目录？

在 `main()` 里，每爬完一章就调用一次 `update_index()`：

```python
write_chapter_md(...)
entries.append({...})
update_index(book_dir, entries)   # ← 每章后立即更新
```

这样做的好处：**程序意外中断时，已爬的章节不会丢失目录信息**。如果攒到最后再生成目录，中途崩溃就什么都没了。

### 9.2 Dataview 查询块

```python
lines.append(
    "```dataview\n"
    f'TABLE volume AS 卷, chapter AS 章节号\n'
    ...
    "```\n"
)
```

这是 Obsidian 的 Dataview 插件语法，类似 SQL 查询。装了 Dataview 后，这个代码块会渲染成一个动态表格，自动列出所有章节。Python 只是把这段文本原封不动写入文件，本身不处理它。

### 9.3 卷分组与链接生成

```python
current_vol = None
for e in entries:
    vol = e["vol"]
    if vol != current_vol:
        lines.append(f"\n## {vol if vol else '正文'}\n")
        current_vol = vol

    link_target = e["rel_path"].replace("\\", "/").removesuffix(".md")
    display = f"第{e['chap_num']:04d}章 " + re.sub(...)
    lines.append(f"- [[{link_target}|{display}]]")
```

**分组逻辑**：用变量 `current_vol` 记住"当前输出的是哪一卷"。每次遇到新卷名，就先输出一个 `## 卷名` 标题，然后输出该卷的章节列表。这个技巧叫**"游标法"**，在很多列表分组场景中都会用到。

**`[[链接路径|显示文字]]`**：Obsidian wiki 链接的格式，`|` 左边是文件路径，右边是显示文字。`.removesuffix(".md")` 去掉 .md 后缀，因为 Obsidian 链接不需要后缀。

---

## 10. 第七部分：Playwright 抓取单章

这是整个项目的**核心**，也是最复杂的部分。

```python
async def scrape_chapter(page, url: str) -> tuple[str, str, str | None]:
```

注意函数定义用了 `async def`，这表示它是一个**协程函数**，必须用 `await` 来调用。

### 10.1 导航到页面

```python
await page.goto(url, wait_until="networkidle", timeout=30000)
await page.wait_for_selector("#content", timeout=15000)
```

- `await`：等待异步操作完成（浏览器加载页面）
- `wait_until="networkidle"`：等到网络请求都完成（不再有新的网络活动）才继续
- `timeout=30000`：超时时间 30 秒（毫秒单位），超过则抛出异常
- `wait_for_selector("#content")`：等待 `#content`（ID为content的元素）出现在页面上

**为什么要等 `#content`？**

网站内容是 JS 动态插入的。`goto()` 完成只代表 HTML 下载完了，不代表 JS 已经把内容塞进页面。等 `#content` 出现，才说明内容区域已经准备好了。

### 10.2 等待 JS 完成段落还原

```python
for _ in range(40):
    visible = await page.evaluate(
        "() => [...document.querySelectorAll('#content > div')]"
        "      .filter(el => el.offsetParent !== null).length"
    )
    if visible > 3:
        break
    await asyncio.sleep(0.3)
```

**这段代码在做什么？**

网站用 JavaScript 把段落打乱后再恢复（反爬措施）。我们用轮询（每0.3秒检查一次）等待还原完成，判断标准是：`#content` 里有多于3个可见的 `div` 元素。

**`page.evaluate()` 是什么？**

它让 Python 在浏览器里执行 JavaScript 代码，并返回结果。语法是传入一个 JS 箭头函数字符串：

```python
await page.evaluate("() => document.title")  # 获取页面标题
```

**`offsetParent !== null` 是什么？**

在 JavaScript 里，如果一个元素不可见（`display: none` 等），它的 `offsetParent` 就是 `null`。这是检测元素是否真正可见的一种方式。

**`for _ in range(40)` 中的 `_` 是什么？**

下划线 `_` 是 Python 惯例，表示"这个循环变量我不需要用"。循环只是为了重复40次，不关心次数。

### 10.3 提取标题

```python
h2_texts = await page.evaluate(
    "() => [...document.querySelectorAll('#content h2')]"
    "      .map(el => el.innerText.trim()).filter(Boolean)"
)
if h2_texts:
    full_title = " ".join(h2_texts)
else:
    full_title = await page.eval_on_selector(
        "#ctitle .title", "el => el.innerText.trim()"
    )
```

**`[...document.querySelectorAll(...)]`**：

`querySelectorAll` 返回 NodeList（类数组），不是真正的数组，不能直接用 `.map()`。用 `[...]`（展开运算符）把它转成真正的数组。

**为什么有两种方案（h2 和 #ctitle .title）？**

这是"防御性编程"。不同章节页面的 HTML 结构可能略有差异，先尝试 h2，失败了再试备用方案。

### 10.4 提取正文（最关键的部分）

```python
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
            clone.querySelectorAll(
                'kbd, tt, samp, acronym, span[style], .mask, .mask2'
            ).forEach(el => el.remove());
            const text = clone.innerText.trim();
            if (text) result.push(text);
        }
        return result;
    }
""")
```

这段 JavaScript 在浏览器里执行，让我们逐步解析：

**为什么要克隆（cloneNode）再处理，而不是直接读取？**

网站在每个段落里混入了隐藏的 `<kbd>`, `<tt>`, `<samp>` 等标签，里面塞了水印文字，但用 CSS 设置为隐藏。如果直接读 `innerText`，隐藏元素的文字也会被读取。

解决方案：克隆这个段落（不影响原始页面），从克隆里删除所有水印标签，再读 `innerText`，这样就只剩干净的正文了。

**`child.nodeType !== 1`**：nodeType=1 表示元素节点（标签），nodeType=3 是文本节点，nodeType=8 是注释。只处理元素节点。

**过滤条件汇总**：
1. 必须是 `DIV` 元素（跳过 h2 标题）
2. `offsetParent !== null`：必须是可见元素
3. `display` 和 `visibility`：双重检查不可见元素

### 10.5 提取下一章链接

```python
next_url = await page.evaluate("""
    () => {
        const a = document.querySelector('#next');
        const href = a ? a.href : null;
        return (href && !href.endsWith('#') && !href.endsWith('/'))
               ? href : null;
    }
""")
```

- `document.querySelector('#next')`：找 ID 为 `next` 的元素（"下一章"按钮）
- `href.endsWith('#')`：`#` 是页面内锚点，不是真正的下一章链接
- `href.endsWith('/')`：`/` 结尾通常是首页链接

如果没有有效的下一章链接，返回 `null`（在 Python 里变成 `None`），`main()` 会检测到这个信号然后停止循环。

---

## 11. 第八部分：主流程 main()

### 11.1 函数签名和导入检查

```python
async def main():
    try:
        from playwright.async_api import async_playwright
    except ImportError:
        print("❌ 请先执行：pip install playwright && playwright install chromium")
        return
```

**为什么在函数内部 import，而不是放在文件顶部？**

这是一个"延迟导入"技巧。如果用户没装 playwright，程序不会在启动时就崩溃报一长串错误，而是给出友好的提示信息。放在函数内，只有真正执行到这里才会检查。

### 11.2 初始化目录和状态

```python
vault = Path(OBSIDIAN_VAULT_PATH)
if not vault.exists():
    print(f"❌ Vault 路径不存在，请检查：\n   {OBSIDIAN_VAULT_PATH}")
    return

book_dir = vault / safe_name(BOOK_TITLE)
book_dir.mkdir(parents=True, exist_ok=True)

entries: list[dict] = []
chapter_count = 0
current_url = START_URL
```

**类型注解 `entries: list[dict]`**：说明 entries 是一个列表，每个元素是字典。帮助自己和别人理解数据结构。

### 11.3 启动 Playwright 浏览器

```python
async with async_playwright() as p:
    browser = await p.chromium.launch(
        headless=True,
        args=["--no-sandbox", "--disable-setuid-sandbox"],
    )
    ctx = await browser.new_context(
        user_agent=(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 ..."
        ),
        locale="zh-CN",
    )
    page = await ctx.new_page()
```

**`async with`**：上下文管理器的异步版本。确保代码块结束后，无论是否发生异常，浏览器都会被正确关闭（释放资源）。

**`headless=True`**：无界面模式，浏览器在后台运行，你看不到窗口。改成 `False` 可以看到浏览器窗口，方便调试。

**为什么要设置 `user_agent`？**

User-Agent 是浏览器在访问网站时"自报家门"的字符串。Playwright 默认的 UA 里有"HeadlessChrome"字样，很多网站会识别并拒绝。设置成正常浏览器的 UA，伪装成普通用户。

**层次结构**：`playwright → browser → context → page`

- `browser`：一个浏览器实例（Chrome）
- `context`：类似"无痕模式"，独立的 cookies/缓存环境
- `page`：一个标签页

### 11.4 主循环

```python
while current_url and chapter_count < MAX_CHAPTERS:
    try:
        print(f"[{chapter_count + 1:>4}] 抓取 → {current_url}")

        full_title, content, next_url = await scrape_chapter(page, current_url)
        vol_name, chap_name, chap_num = parse_title(full_title)

        filepath, rel_path = write_chapter_md(
            book_dir, vol_name, chap_name, chap_num, content, current_url
        )

        entries.append({
            "vol":       vol_name,
            "chap_name": chap_name,
            "chap_num":  chap_num,
            "rel_path":  rel_path,
        })
        update_index(book_dir, entries)

        print(f"       ✓  {full_title}  [{len(content):,} 字]")
        chapter_count += 1
        current_url = next_url
        if current_url:
            await asyncio.sleep(DELAY_SECS)

    except Exception as exc:
        # 失败处理（见下文）
```

**`while current_url and chapter_count < MAX_CHAPTERS`**：

两个停止条件：
1. `current_url` 为 None（已到最后一章，没有下一章链接）
2. `chapter_count >= MAX_CHAPTERS`（达到最大章数限制）

**Python 的 `and` 短路求值**：如果 `current_url` 已经是 `None`（假值），第二个条件就不会被检查了。

**`f"[{chapter_count + 1:>4}]"` 中的 `:>4`**：右对齐，最小宽度4。让序号整齐排列：
```
[   1] 抓取 → ...
[  10] 抓取 → ...
[ 100] 抓取 → ...
```

**`len(content):,`**：`:,` 格式化大数字，每3位加逗号。`12345` 显示为 `12,345`。

### 11.5 错误处理与重试

```python
    except Exception as exc:
        print(f"       ✗  失败：{exc}")
        print("          等待 5 秒后重试…")
        await asyncio.sleep(5)
        try:
            # 完全相同的代码，再试一次
            ...
        except Exception as exc2:
            print(f"          重试仍失败，终止：{exc2}")
            break
```

**为什么要重试？**

网络请求不可靠：服务器可能临时过载、网络抖动、超时。一次失败不代表永远失败，等几秒再试一次往往能成功。

**为什么只重试一次，不是无限重试？**

无限重试有风险：如果链接本身无效，会陷入死循环。重试一次是合理的平衡。

**`break` 的作用**：跳出 `while` 循环，结束整个爬取过程。

---

## 12. 数据流动全貌

```
网络 URL
   │
   ▼
scrape_chapter()        ← Playwright 控制浏览器访问
   │
   ├─ full_title: "第一卷 七玄门风云 第一章 山边小村"
   ├─ content:    "韩立无奈地看着...（正文）"
   └─ next_url:   "https://www.hetushu.com/.../24722.html"
   │
   ▼
parse_title(full_title)
   │
   ├─ vol_name:  "第一卷 七玄门风云"
   ├─ chap_name: "第一章 山边小村"
   └─ chap_num:  1
   │
   ▼
write_chapter_md()      ← 写入 .md 文件
   │
   ├─ filepath:  Path(".../凡人修仙传/第一卷 七玄门风云/第0001章 山边小村.md")
   └─ rel_path:  "第一卷 七玄门风云/第0001章 山边小村.md"
   │
   ▼
entries.append({...})   ← 追加到章节列表
   │
   ▼
update_index()          ← 更新 00_目录.md
   │
   ▼
current_url = next_url  ← 继续下一章
```

---

## 13. 常见问题与排错指南

### Q1：运行报错 `ModuleNotFoundError: No module named 'playwright'`

**原因**：没有安装 playwright。

**解决**：
```bash
pip install playwright
playwright install chromium
```

### Q2：运行报错 `❌ Vault 路径不存在`

**原因**：`OBSIDIAN_VAULT_PATH` 配置错误。

**解决**：
- Mac：在 Finder 里找到你的 Vault 文件夹，右键 → "获取简介"，复制"位置"
- Windows：在文件浏览器地址栏里看路径

### Q3：爬了几章之后停止了

**原因**：可能是网络超时、服务器拒绝了请求，或者到达了最后一章。

**解决**：查看终端里的错误信息。如果是网络问题，调大 `DELAY_SECS`（比如改成 3）；如果是被封 IP，换个网络再试。

### Q4：正文里有乱码或奇怪字符

**原因**：水印清洗不完整，或者网站更新了反爬策略。

**解决**：把 `headless=True` 改成 `headless=False`，手动看浏览器里的页面，对比实际内容，调整 `_WATERMARK_RE` 正则。

### Q5：文件名有下划线，原来有特殊字符

**原因**：`safe_name()` 把非法字符替换成了 `_`，这是预期行为。

---

## 14. 进阶思考：如果让你改造这个项目

当你完全理解这个项目后，可以尝试以下改造练习：

### 🔰 初级：改造配置
1. 把配置区改成从命令行参数读取（用 `argparse` 模块）
2. 添加一个配置项，让用户选择输出格式（纯文本 `.txt` 或 `.md`）

### 🔷 中级：增加功能
1. **断点续爬**：记录已爬章节号到文件，下次运行跳过已有章节
2. **进度条**：用 `tqdm` 库显示进度条
3. **日志系统**：用 `logging` 模块替换 `print`，支持写入日志文件

### 🔶 高级：架构改进
1. **并发爬取**：用 `asyncio.gather()` 同时爬多章（需要处理速率限制）
2. **适配多网站**：把网站特定的选择器（`#content`, `#next`）抽象成配置，支持爬不同小说网站
3. **导出为 EPUB**：用 `ebooklib` 把章节打包成 epub 电子书格式

---

## 总结

这个项目涵盖了很多实用的编程技术：

| 技术 | 用途 |
|------|------|
| `asyncio` + `async/await` | 异步编程，配合 Playwright |
| `Playwright` | 控制真实浏览器，处理 JS 渲染 |
| 正则表达式 `re` | 文字清洗、标题解析 |
| `pathlib.Path` | 现代文件系统操作 |
| 错误处理 `try/except` | 网络不稳定时的健壮性 |
| 格式化字符串 f-string | 动态生成文件内容 |
| YAML frontmatter | 结构化元数据，供工具读取 |

作为一个"有 Python 基础的小白"看完这个项目，你已经接触了真实工程代码的绝大多数核心概念。恭喜你！

---

*文档生成时间：2024 年 | 适用脚本版本：hetushu_scraper.py v3*
