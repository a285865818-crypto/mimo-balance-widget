# 安全政策（Security Policy）

## 项目性质与威胁模型

本项目是运行在 **Root Android 设备上、仅操作使用者自有账号凭据** 的余额获取脚本集。它的信任边界是：

- `root/*.sh`、`auth/*.py` 以 root 权限运行，可以读取设备 root 权限内的资源；
- 所有外部输入（API 响应、触发文件）都视为**不可信输入**，消费前必须消毒（见下文「代码层的安全设计」）。

**不在威胁模型内**：已获得设备 root 权限的攻击者。root 环境下任何本地防线都可能被绕过，凭据安全依赖设备本身的物理与系统安全。

## 凭据处理承诺

1. 仓库内**永远不含**真实账号、密码、serviceToken、签名 `sign`、GitHub PAT、签名密钥库。
2. 真实凭据只存设备本地，权限 600，目录 700，且被 `.gitignore` 严格排除。
3. 敏感值一律通过环境变量或 `config.sh`（不入库）注入，代码中只保留占位符。

## 报告漏洞

如发现安全问题（命令注入、凭据泄漏等）：

1. **优先私下报告**：GitHub 仓库页 → Security → Report a vulnerability（Security Advisories），或站内私信仓库所有者。
2. **不要**公开提 issue，也不要附带任何真实凭据的 PoC。
3. 核实后会尽快回复与修复，确认属实的高危问题优先处理。

## 凭据泄漏应急流程

任何使用者若把真实凭据提交到公开位置（含 git 历史），请立即：

1. 修改小米账号密码，退出所有登录会话；
2. 撤销已暴露的 GitHub PAT（Settings → Developer settings → Fine-grained tokens → Delete）；
3. 删除或重置泄漏的 `cookies.txt` / `secrets.json` / `session.json`，重新登录获取新凭据；
4. 注意「删除文件」不等于清除历史，必要时用 `git filter-repo` 重写历史或直接删除仓库重建。

## 代码层的安全设计

- API 响应拼接进 shell 命令前剥离全部 shell 元字符（`root/mimo_balance.sh` 的 `post()` 消毒函数）；
- 脚本对外部输入只做「删除/读数字」，绝不 eval 或执行文件内容；
- 凭据文件 600、目录 700；`cookies.txt` 等由 `.gitignore` 排除，无法被意外提交；
- `mimo_balance.sh` 通过 `am startservice` 把数据推送给本机的配套展示组件（需自行开发，见 README「配套 App」；目标组件硬编码为 `com.mimo.balance/.UpdateService`）时，同样经 `post()` 消毒后再拼命令；组件不可用时降级为 `cmd notification` 通知卡片，不影响取数安全；
- 登录脚本只在使用者显式执行时运行，不会后台驻留或自动上传任何数据。
