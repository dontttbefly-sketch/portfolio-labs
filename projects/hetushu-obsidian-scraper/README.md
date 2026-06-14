# 和图书小说爬虫到 Obsidian

这是一个面向学习和个人整理的 Python 爬虫示例。它使用 Playwright 打开真实浏览器，读取网站 JavaScript 渲染后的章节内容，清洗水印，并按“书名 / 卷 / 章节”的结构写入 Obsidian Markdown 文件。

## 数据流动

```text
起始章节 URL
  -> Playwright 打开网页并等待 JS 执行
  -> 读取标题、正文段落、下一章链接
  -> 清洗水印和异常字符
  -> 解析卷号、章号、章节名
  -> 写入 Obsidian Markdown 文件
  -> 更新 00_目录.md
  -> 继续下一章
```

## 安装

建议使用 Python 3.10 或更高版本。

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
playwright install chromium
```

## 配置

复制示例配置：

```bash
cp .env.example .env
```

然后编辑 `.env`：

| 配置项 | 说明 |
| --- | --- |
| `OBSIDIAN_VAULT_PATH` | 你的 Obsidian 笔记库路径，例如 `~/Obsidian` |
| `BOOK_TITLE` | 输出文件夹使用的书名 |
| `START_URL` | 第一章页面地址 |
| `MAX_CHAPTERS` | 最多抓取多少章，测试时建议先设为 `1` 或 `3` |
| `DELAY_SECS` | 每章之间的等待秒数，建议保留 1 秒以上 |

## 运行

```bash
python xiaoshuo.py
```

运行成功后，脚本会在 Obsidian 笔记库中生成：

```text
BOOK_TITLE/
  00_目录.md
  001_第一卷 .../
    第0001章 ....md
```

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `xiaoshuo.py` | 主程序 |
| `.env.example` | 配置模板，可复制为本地 `.env` |
| `requirements.txt` | Python 依赖 |
| `hetushu爬虫项目教学文档.md` | 逐步讲解脚本设计思路的教学文档 |
| `SECURITY.md` | 公开发布前的安全提醒 |

## 安全和版权提醒

- 不要把 `.env`、Cookie、账号、Token、真实个人路径上传到 GitHub。
- 不要把抓取出来的小说正文文件上传到公开仓库。
- 请只抓取你有权保存或学习研究的内容，并遵守目标网站的服务条款、版权要求和访问频率限制。
- 测试时先把 `MAX_CHAPTERS` 设小，确认输出正常后再逐步增加。

## 常见问题

### 提示 Vault 路径不存在

检查 `.env` 里的 `OBSIDIAN_VAULT_PATH` 是否指向真实存在的 Obsidian 笔记库。路径可以使用 `~` 表示用户目录。

### 提示需要安装 Playwright

先激活虚拟环境，再执行：

```bash
pip install -r requirements.txt
playwright install chromium
```

### 页面加载失败或抓取很慢

可能是网络、网站反爬或访问频率太高。可以增大 `DELAY_SECS`，并减少 `MAX_CHAPTERS` 做小范围测试。
