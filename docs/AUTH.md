# MiMo 登录与续期链路

版本：1（2026-10-21）

## 1. 获取 serviceToken

```
GET account.xiaomi.com/pass/serviceLogin?sid=api-platform → 登录页
→ POST serviceLoginAuth2（账号 + 密码 MD5 大写哈希）
→ 开启 2FA 时：identity/list 拿 applyToken → sendPhoneTicket 发短信
   （form: _flag=4, applyToken, sid）
→ verifyPhone 验码（form: _flag=4, applyToken, sid, ticket=验证码）
→ 跟随 Location 的 302 重定向链，最终 Set-Cookie 中即 serviceToken
（api-platform_serviceToken，有效期约 30 天）
```

**手动提取（推荐，风控风险更低）**：在 Edge 手动登录一次 MiMo 并打开余额页，serviceToken 会落在浏览器进程里，用 `renew_from_edge.sh` 扫内存提取（Cookies 库是 `v10$` 自定义加密，直接解密不可行）。

## 2. 凭据落盘

CookieJar 导出为 Netscape 格式 `cookies.txt`，权限 600，目录 700。核心字段：

- `api-platform_serviceToken` — 调接口的凭证
- `userId` — 平台用户 ID

## 3. 实测

```sh
curl -b cookies.txt https://platform.xiaomimimo.com/api/v1/tokenPlan/detail
# 返回 code: 0 即成功（注意必须用 -b 文件，不能用 -H "Cookie:" 塞头）
```

## 4. 日常刷新

- 守护每 2 分钟请求同一接口查余额；余额接口有约 5 分钟平台侧延迟。
- 返回无 balance 时，先走一次 SSO 兑换 URL 刷新 serviceToken 再重试。
- **SSO 兑换 callback 必须带平台签名 `sign`，缺签名兑换直接 401。**
- serviceToken 约 30 天过期，过期后重走第 1 步（或直接 renew_from_edge.sh）。

## 5. 风控注意事项

- `account.xiaomi.com` 对密集认证请求有风控，会掐 TLS 连接，自动登录务必留冷却时间。
- 2FA 自动链路（login_sms.py）可跑通，但风险较高；保守做法是登录掉了再人工提供密码/验证码，优先走 Edge 内存扫描。
- 凭据文件绝不要提交到 git（见 .gitignore），泄漏即等同账号泄漏，需立即改密并重新登录。
