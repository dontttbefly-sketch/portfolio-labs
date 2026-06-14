# 本地 Markdown 到微信公众号草稿箱发布工具

这个工具用于把本地 Markdown 文章转换成微信公众号图文草稿。第一版只创建草稿，不自动发布、不群发，方便你在公众号后台人工检查后再发布。

默认排版风格参考 Vibe Coding 长文教程：清晰分节、代码块友好、表格可读、适合持续发布 AI 编程 / Codex 协作开发日记。

## 整体链路

```text
本地 Markdown
  -> check 检查 frontmatter、图片和敏感信息
  -> preview 生成本地 HTML 预览
  -> draft 上传正文图片和封面
  -> 微信公众号草稿箱
  -> 人工检查后发布
```

## 准备工作

### 1. 准备微信公众号开发信息

在微信公众号后台找到：

```text
设置与开发 -> 基本配置 -> 公众号开发信息
```

需要填写：

```text
AppID
AppSecret
```

同时确认后台已经配置好接口权限和 IP 白名单。创建草稿需要调用微信官方接口，所以当前电脑公网 IP 需要在公众号后台白名单中。

### 2. 填写 `.env`

复制模板：

```bash
cp .env.example .env
```

填写真实值：

```text
WECHAT_APP_ID=你的公众号 AppID
WECHAT_APP_SECRET=你的公众号 AppSecret
WECHAT_AUTHOR=空杯
WECHAT_DEFAULT_COVER=assets/default-cover.png
```

`.env` 不会提交到 Git。

## 写文章

文章默认放在 `articles/` 目录。

每篇文章顶部需要 frontmatter：

```yaml
---
title: "文章标题"
digest: "公众号摘要，建议 60-120 字"
author: "空杯"
cover: "../assets/default-cover.png"
source_url: ""
show_cover_pic: false
---
```

字段说明：

| 字段 | 是否必填 | 说明 |
|---|---|---|
| `title` | 必填 | 公众号草稿标题 |
| `digest` | 必填 | 公众号摘要 |
| `author` | 可选 | 不填时使用 `.env` 的 `WECHAT_AUTHOR` |
| `cover` | 可选 | 不填时使用 `.env` 的默认封面 |
| `source_url` | 可选 | 原文链接 |
| `show_cover_pic` | 可选 | 是否在正文顶部显示封面 |

项目自带示例：

```text
articles/sample.md
```

## 常用命令

### 检查文章

```bash
npm run check -- articles/sample.md
```

会检查：

- `title` 是否存在。
- `digest` 是否存在。
- 封面图是否存在。
- 正文图片路径是否存在。
- 是否有疑似 token、webhook、open_id、chat_id 等敏感内容。

### 生成本地预览

```bash
npm run preview -- articles/sample.md
```

生成文件：

```text
.preview/sample.html
```

可以用浏览器打开预览排版。

### 创建微信公众号草稿

```bash
npm run draft -- articles/sample.md
```

这个命令会：

1. 获取并缓存 `access_token`。
2. 上传封面图，得到 `thumb_media_id`。
3. 上传正文里的本地图片，替换成微信公众号图片 URL。
4. 调用新增草稿接口。
5. 在终端输出草稿 `media_id`。

然后你到微信公众号后台草稿箱人工检查并发布。

## 图片规则

正文图片使用普通 Markdown：

```markdown
![说明文字](../assets/example.png)
```

本地图片会在 `draft` 时自动上传到微信公众号，并替换成微信返回的图片 URL。

支持的常见图片类型：

```text
png, jpg, jpeg, gif, webp
```

封面图默认是：

```text
assets/default-cover.png
```

你可以替换这张图，或者在单篇文章 frontmatter 里指定其他封面。

## 支持的 Markdown

第一版支持：

- H1 / H2 / H3 标题
- 段落
- 引用
- 无序列表
- 有序列表
- 表格
- 代码块
- 行内代码
- 加粗、斜体
- 链接
- 本地图片

Mermaid 代码块第一版会按普通代码块保留，不做图形渲染。

## 缓存文件

工具会生成 `.cache/`：

| 文件 | 作用 |
|---|---|
| `access-token.json` | 缓存微信 access_token |
| `uploaded-images.json` | 缓存正文图片 hash 到微信 URL 的映射 |
| `uploaded-covers.json` | 缓存封面 hash 到 thumb_media_id 的映射 |

`.cache/` 不会提交到 Git。

## 敏感信息安全

不要公开：

- `.env`
- `.cache/`
- `WECHAT_APP_SECRET`
- `access_token`
- 真实 webhook
- 真实 `open_id`、`chat_id`、app token、table id、view id

发布前可以运行：

```bash
rg -n "secret|access_token|open-apis/bot/v2/hook|oc_[A-Za-z0-9]|ou_[A-Za-z0-9]|cli_[A-Za-z0-9]|tbl[A-Za-z0-9]|vew[A-Za-z0-9]" .
```

## 常见问题

### 提示缺少 `WECHAT_APP_ID`

说明 `.env` 没填或当前命令不在项目根目录运行。

确认：

```text
WECHAT_APP_ID=...
WECHAT_APP_SECRET=...
```

### 获取 access_token 失败

常见原因：

- AppID 或 AppSecret 填错。
- 当前电脑公网 IP 没加到公众号后台白名单。
- 公众号接口权限不足。

### 草稿创建成功但排版还要调

这是正常的。第一版目标是把内容送到草稿箱，最后你仍然可以在公众号后台人工微调。

## 官方接口参考

- [获取 access_token](https://developers.weixin.qq.com/doc/offiaccount/Basic_Information/Get_access_token.html)
- [上传图文消息内图片](https://developers.weixin.qq.com/doc/offiaccount/Asset_Management/Adding_Images_to_Articles.html)
- [新增永久素材](https://developers.weixin.qq.com/doc/offiaccount/Asset_Management/Adding_Permanent_Assets.html)
- [新增草稿](https://developers.weixin.qq.com/doc/offiaccount/Draft_Box/Add_draft.html)
