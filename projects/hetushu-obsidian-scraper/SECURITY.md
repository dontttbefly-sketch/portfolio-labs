# 安全说明

公开发布前请确认以下内容没有被提交：

- `.env`、Cookie、Token、账号密码、Webhook、App Secret。
- 个人真实路径、客户信息、内部项目名、人员 ID。
- 抓取出来的小说正文、批量导出的数据文件。
- `.venv/`、`.idea/`、缓存、日志和临时文件。

本项目的 `.gitignore` 已经默认忽略这些常见敏感文件。上传 GitHub 前仍建议执行一次：

```bash
git status --short --ignored
```

确认只有源码、说明文档和示例配置会被发布。
