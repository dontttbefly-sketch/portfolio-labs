---
title: "从调研到落地：一次 Vibe Coding 自动化项目复盘"
digest: "这是一篇示例文章，用来测试本地 Markdown 转微信公众号草稿箱的完整链路。"
author: "空杯"
cover: "../assets/default-cover.png"
source_url: ""
show_cover_pic: false
---

# 从调研到落地：一次 Vibe Coding 自动化项目复盘

这是一篇示例文章，用来验证 Markdown 标题、段落、引用、列表、表格和代码块在公众号草稿里的显示效果。

## 1. 初始问题

最开始的问题往往很朴素：

> 我有一个重复工作，能不能让 AI 和脚本一起帮我自动完成？

Vibe Coding 的价值不是一开始就知道答案，而是边调研、边试错、边把模糊需求变成可运行工具。

## 2. 示例表格

| 阶段 | 目标 | 结果 |
|---|---|---|
| 调研 | 找到真实限制 | 明确接口边界 |
| 实验 | 跑通最小链路 | 确认可行 |
| 落地 | 做成工具 | 可以复用 |

## 3. 示例代码

```bash
npm run check -- articles/sample.md
npm run preview -- articles/sample.md
```

## 4. 结论

当一个流程能被写成 Markdown、脚本和文档，它就不只是一次临时解决方案，而是可以持续复用的个人能力。
