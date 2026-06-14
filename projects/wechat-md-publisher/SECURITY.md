# 安全说明

这个工具会读取微信公众号 AppID/AppSecret，并调用微信官方接口创建草稿。公开上传或分享前，请确认以下文件不会泄露。

## 不要提交或公开

- `.env`
- `.cache/`
- `access_token`
- 微信公众号 AppSecret
- 真实 webhook 地址
- 真实 `open_id`、`chat_id`、app token、table id、view id
- 私密客户名称、内部项目名称、员工信息

## 建议扫描

```bash
rg -n "secret|access_token|open-apis/bot/v2/hook|oc_[A-Za-z0-9]|ou_[A-Za-z0-9]|cli_[A-Za-z0-9]|tbl[A-Za-z0-9]|vew[A-Za-z0-9]" .
```

占位符如 `cli_xxxxx`、`oc_xxxxx` 可以保留；真实值请替换成占位符。
