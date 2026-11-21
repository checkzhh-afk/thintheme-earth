# 当前一键安装与三网去程

新 VPS：登录监控后台 → 自动添加（需开启自动发现）→ Linux / 当前用户（root 或 sudo）→ 填名称 → 复制完整命令执行。命令已包含认证，通过 --secret-stdin 传入，无需再输入密钥。不要公开复制的认证命令。

已有 VPS：在后台该节点行点击 📋，选择 Linux / 当前用户，复制完整命令执行；也可以使用下面不含凭据的通用更新命令：

```bash
bash -c 'set -e; umask 077; f=$(mktemp); trap '\''rm -f -- "$f"'\'' EXIT; curl --noproxy "*" -fsSL --proto "=https" --proto-redir "=https" --connect-timeout 10 --max-time 90 --retry 1 https://raw.githubusercontent.com/checkzhh-afk/thintheme-earth/main/cf-install.sh -o "$f"; bash -n "$f"; bash "$f"'
```

安装自动提交双栈 TCP80 去程任务，并执行 doctor/status/verify。已有身份、名字、计费流量设置保留，已有兼容 Agent 复用。新机固定 Agent v1.1.3 校验下载，默认HTTP/60秒和TCP探测；已有机保留原传输配置。

后台节点的 🌐 按钮可选择地址族和TCP端口后测三网去程。VPS也可执行 `cf-monitor route-out`，或 `cf-monitor route-out ipv4 443`；用 `cf-monitor route-out-status` 查询。任务在Worker/D1后台推进，关闭页面继续；成功识别自动更新前台去程并保存旧值审计，包括之前人工去程标签。失败保留历史标记，回程不变。

国内探针必须同时符合国家和运营商ASN，实际城市以结果为准；无探针、终点无响应、证据不足都不伪造线路。通常需数分钟到十几分钟；不保证全部三网双栈有结果。选择VPS实际服务端口。安装验收ready不代表所有线路已测通。

公开入口不保存密钥。手动只用 --name 而未提供 --secret-stdin 时仍隐藏询问密钥；后台生成命令无需二次输入。完整流程针对Linux root/sudo，不在VPS引入Node/Python/Docker或新的常驻进程。

Windows诊断入口 `cf-route-out.ps1` 保留：ThreeNet默认只保存证据，-Publish仍保护人工锁及新任务结果；Local只代表当前宽带，不能代表三网，不自动上传。跨AI操作见 `cf-monitor-skill/SKILL.md`。

## 已有 VPS：一键刷新 / 自选菜单

已有辅助监控的VPS可直接执行，无需重装或输入密钥。**新增IPv6建议选1“全部刷新”**，它先重新识别网络和启用可用测点。

```bash
bash -c 'set -e; umask 077; f=$(mktemp); trap '\''rm -f -- "$f"'\'' EXIT; curl --noproxy "*" -fsSL --proto "=https" --proto-redir "=https" --connect-timeout 10 --max-time 90 --retry 1 https://raw.githubusercontent.com/checkzhh-afk/thintheme-earth/main/cf-refresh.sh -o "$f"; bash -n "$f"; bash "$f"'
```

菜单：1全部刷新；2网络配置；3谷歌送中；4三网回程；5提交三网去程；6查看状态；0退出。每次执行选择一项后退出。选1或5时询问去程TCP端口，回车默认80，可填写实际监听端口如443。

无需菜单、直接全部刷新：

```bash
bash -c 'set -e; umask 077; f=$(mktemp); trap '\''rm -f -- "$f"'\'' EXIT; curl --noproxy "*" -fsSL --proto "=https" --proto-redir "=https" --connect-timeout 10 --max-time 90 --retry 1 https://raw.githubusercontent.com/checkzhh-afk/thintheme-earth/main/cf-refresh.sh -o "$f"; bash -n "$f"; bash "$f" --all'
```

需要去程TCP443时，最后改为 `bash "$f" --all --port=443`。端口仅用于去程测量，不修改防火墙、服务或面板延迟探测协议。也支持 `--network / --google / --return / --outbound / --status` 单项执行。

全部刷新执行：重新识别双栈网络并更新配置 → 双栈谷歌 → 双栈三网回程 → 提交双栈去程 → 验收。谷歌/回程绕过常规定时冷却，仍使用现有测点、分类和人工锁规则。配置失败就停止，其他失败会明确提示。入口串行加锁，沿用回程低内存保护，不新增常驻服务；不升级Agent或辅助脚本。

延迟、丢包等待Agent继续上报；三网去程在Worker后台测，成功识别自动更新面板，`cf-monitor route-out-status`查询进度。验收退出3表示尚未就绪，需看输出区分等Agent上报或其他问题；“已提交”和“验收通过”都不保证所有线路识别成功。没有辅助脚本时先运行上方安装/更新命令。
