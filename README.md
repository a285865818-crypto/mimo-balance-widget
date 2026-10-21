# MiMo 余额获取方案

在 Root Android 设备上抓取小米 MiMo 平台 token 余额的脚本方案：shell 守护每 2 分钟请求一次余额接口，通过**通知栏卡片**展示，serviceToken 过期后支持一键续期。

> 本仓库只包含**余额获取、登录与续期**相关的脚本和文档，**不含 Android App**。脚本默认以通知栏卡片展示；想要悬浮窗等进阶效果，可自行开发配套 App（集成方式见「配套 App」一节）。

---

## ⚠️ 免责声明（Disclaimer）

**本项目与小米公司、MiMo 平台、微软 Edge 浏览器均无任何关联，未经授权，不是官方工具。**

1. 本项目按 **"现状（AS IS）"** 提供，不附带任何形式的明示或暗示保证，包括但不限于适销性、特定用途适用性和不侵权的保证。在任何情况下，作者或贡献者均不对任何索赔、损害或其他责任负责。
2. 本项目**仅供学习与研究**登录链路与 root 脚本的技术实现，**不提供任何服务承诺**，不承诺持续可用、不承诺兼容未来接口变更。
3. **使用本项目的一切后果由使用者自行承担**：包括但不限于账号被风控、功能受限、账号封禁、数据丢失、设备异常等。作者不承担任何直接或间接损失。
4. 逆向登录接口、自动化 2FA、读取浏览器进程内存等行为**可能违反小米/微软的服务条款**以及使用者所在地区的法律法规。使用者有责任自行确认行为的合法性。
5. 如权利方认为本项目侵权，请通过 GitHub 私信联系仓库所有者，核实后将配合下架处理。

## 🔒 安全声明（Security）

1. **凭据主权**：本项目只处理**使用者自己账号**的凭据（serviceToken、userId），不包含也不鼓励获取他人凭据的任何功能。`auth/scan_edge.py` 从浏览器进程提取的是使用者自己登录时产生的 token，仅用于自动续期。
2. **凭据不入库**：仓库内不含任何真实账号、密码、token、签名密钥、签名密钥库。真实凭据存放于设备本地（`config.sh` / `secrets.json` / `cookies.txt`），权限 600/700，且已被 `.gitignore` 严格排除。
3. **不执行不可信输入**：脚本对外部输入（API 响应、触发文件）只做「删除/读数字」，绝不 eval 或执行文件内容；API 响应拼进 shell 命令前做元字符消毒（见 `root/mimo_balance.sh` 的 `post()` 函数）。
4. **漏洞与安全问题**：如发现安全问题，请通过 GitHub 私信或 Security Advisories 联系仓库所有者，**不要公开提 issue**。
5. **凭据泄漏应急**：若真实 `cookies.txt` / `secrets.json` / 令牌被提交到任何公开位置，请立即：① 修改小米账号密码；② 退出所有登录会话；③ 撤销已暴露的 GitHub PAT；④ 重新登录并生成新凭据。

## ☢️ 风险警告（Warning）

- **账号风险**：自动化登录和接口轮询会触发小米风控，表现为连接被掐、要求重新验证，严重时账号受限或封禁。轮询频率请勿调得过密。
- **设备风险**：本项目依赖 Root（KernelSU/Magisk）。Root 环境本身削弱设备安全模型；错误的脚本改动可能影响系统稳定性。操作前请确保你了解每条命令的含义。
- **浏览器内存扫描**：`scan_edge.py` / `renew_from_edge.sh` 需要读取浏览器进程内存（`/proc/<pid>/mem`），这类行为可能被安全软件/杀毒引擎误报为恶意行为，请知悉。
- **接口时效**：MiMo 平台接口属未公开接口，随时可能变更、加签或下线，届时本项目功能将失效。余额接口有约 5 分钟延迟，显示值仅供参考，**不构成任何账务依据**。
- **受监管环境**：如所在地区对账号自动化、逆向工程等行为有特别监管要求，使用前请咨询专业人士。

---

## 工作流程

```
┌────────────────────────────────────────────────────────────┐
│ mimo_balance.sh   取数守护：每 2 分钟 curl 余额接口           │
│                   → 通知栏卡片展示余额/现金/赠送/冻结         │
│                   → 记录余额历史（30 天滚动）                 │
│ mimo_watchdog.sh  看门狗：守护进程死掉自动拉起（可选）         │
│ renew_from_edge.sh 一键续期：扫 Edge 内存提取 serviceToken    │
│ auth/login_sms.py  全自动 2FA 登录（备用，风控风险较高）        │
└────────────────────────────────────────────────────────────┘
```

- 登录与续期链路的完整协议见 [docs/AUTH.md](docs/AUTH.md)。
- 脚本若检测到本机装有配套展示组件（闭源，非本仓库内容），会把数据推送给它渲染；没有则自动降级为通知栏卡片。

## 配套 App（可选，需自行开发）

**开箱即用的只有通知栏卡片**，这已覆盖余额获取的全部核心功能。如果你想要悬浮窗、转屏同步、历史趋势图等更丰富的展示效果，需要**自行编写配套 Android App 并构建打包**——本仓库不包含 App 源码、构建产物或预制安装包。

自行开发时的集成点（均以开源脚本为准，无其他私有约定）：

- **组件约定（硬编码）**：脚本推送的目标是 `am startservice -n com.mimo.balance/.UpdateService`，即你的 App 需使用包名 `com.mimo.balance` 并实现 `.UpdateService` 服务（或者自行修改脚本中的目标）；extras 键名为 `title` / `text` / `bal` / `cash` / `gift` / `frz` / `time` / `hist` / `days`；
- 点击刷新：App 写入触发文件 `/data/data/com.mimo.balance/files/refresh.req`，守护每 10 秒轮询并删除（只删不执行）；
- 降级保障：展示组件不存在或调用失败时，脚本自动回落到 `cmd notification` 通知卡片，取数流程不受影响；
- 为避免任意应用伪造调用，你的组件建议同样声明权限门槛（如 `android:permission="android.permission.DUMP"`）。

## 目录

| 路径 | 内容 |
|---|---|
| `root/` | 取数守护、看门狗、一键续期脚本 |
| `auth/` | 全自动 2FA 登录（`login_sms.py`）、Edge 内存扫描（`scan_edge.py`） |
| `config/` | 配置模板（真实配置不入库） |
| `docs/` | 登录与续期链路文档 |

## 快速开始

前置：Root（KernelSU/Magisk）、KernelSU busybox（脚本默认 `/data/adb/ksu/bin/busybox`，其他 root 方案改 `BB=` 变量）、curl、Python 3（仅 auth 脚本需要）。

1. **部署脚本**

   ```sh
   adb push root/ /data/adb/mimo_balance/
   adb push auth/ /data/adb/mimo_balance/auth/
   adb shell su -c 'chmod 700 /data/adb/mimo_balance /data/adb/mimo_balance/auth; chmod 600 /data/adb/mimo_balance/auth/*.py; chmod 755 /data/adb/mimo_balance/*.sh'
   ```

2. **配置凭据**（真实值不入库）

   把 `config/config.example.sh` 复制为 `config.sh`，填入 `MIMO_USER_ID` 和 `MIMO_CB`，随脚本一起 push 到 `/data/adb/mimo_balance/config.sh`（`chmod 600`）。两个值的获取方式见 `docs/AUTH.md` 与模板内注释。

3. **首次登录**（二选一）

   - **手动提取（推荐）**：在 Edge 浏览器手动登录一次 MiMo 平台并打开余额页，然后执行 `sh /data/adb/mimo_balance/renew_from_edge.sh`，从浏览器内存提取 serviceToken。
   - **全自动**：`MIMO_USER=... MIMO_PW=... python3 /data/adb/mimo_balance/auth/login_sms.py prep` → 收到短信验证码后 `python3 /data/adb/mimo_balance/auth/login_sms.py <验证码>`（在设备的 Python 3 环境中执行，如 Linux 容器/Termux）。

4. **验证**

   ```sh
   curl -b /data/adb/mimo_balance/cookies.txt https://platform.xiaomimimo.com/api/v1/tokenPlan/detail
   # 返回 code: 0 即成功
   ```

5. **启动守护**

   ```sh
   su -c 'setsid sh /data/adb/mimo_balance/mimo_balance.sh >/dev/null 2>&1 &'
   su -c 'setsid sh /data/adb/mimo_balance/mimo_watchdog.sh >/dev/null 2>&1 &'
   ```

   启动后通知栏会出现余额卡片，每 2 分钟自动刷新。想要悬浮窗等进阶展示效果，见上文「配套 App（可选，需自行开发）」。

## 注意事项与已知坑

- SSO 兑换 callback 的 `sign` 参数是平台签名，**缺签名兑换直接 401**。
- 改完 `mimo_balance.sh` 必须杀掉 `run.pid` 里的旧守护进程再重启，否则旧进程继续跑旧代码，可能反复 401 触发假告警。
- 余额接口有约 5 分钟平台侧延迟，2 分钟轮询看到的不是实时值。
- `account.xiaomi.com` 有风控，密集认证请求会被掐连接，自动登录请留冷却时间。
- Edge 的 Cookies 库是 `v10$` 自定义加密，直接解密不可行，所以续期走的是进程内存扫描。
- API 响应拼进 shell 命令前已做元字符消毒（改动时必须保持，见 `SECURITY.md` 安全设计）。

## License

[MIT](LICENSE)
