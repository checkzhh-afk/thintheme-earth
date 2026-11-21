# 当前一键安装与三网去程

新 VPS：登录监控后台 → 自动添加（需开启自动发现）→ Linux / 当前用户（root 或 sudo）→ 填名称 → 复制完整命令执行。命令已包含认证，通过 --secret-stdin 传入，无需再输入密钥。不要公开复制的认证命令。

已有 VPS：在后台该节点行点击 📋，选择 Linux / 当前用户，复制完整命令执行；也可以使用下面不含凭据的通用更新命令：

```bash
bash -c 'set -e; umask 077; f=$(mktemp); trap '\''rm -f -- "$f"'\'' EXIT; curl --noproxy "*" -fsSL --proto "=https" --proto-redir "=https" --connect-timeout 10 --max-time 90 --retry 1 https://raw.githubusercontent.com/checkzhh-afk/thintheme-earth/main/cf-install.sh -o "$f"; bash -n "$f"; bash "$f"'
```

安装/更新会自动创建 `/usr/local/bin/cfm` 快捷入口，不再需要第二条安装简称的命令。以后输入 `cfm` 打开菜单，`cfm --update` 更新辅助脚本和菜单，`cfm --status` 看状态，`cfm --all` 全部刷新。菜单第7项也可更新。现有 Agent v1.1.2/v1.1.3 保留，不升级 Agent 版本。

安装自动提交双栈 TCP80 去程任务，并执行 doctor/status/verify。已有身份、名字、计费流量设置保留，已有兼容 Agent 复用。新机固定 Agent v1.1.3 校验下载，默认HTTP/60秒和TCP探测；已有机保留原传输配置。

后台节点的 🌐 按钮可选择地址族和TCP端口后测三网去程。VPS也可执行 `cf-monitor route-out`，或 `cf-monitor route-out ipv4 443`；用 `cf-monitor route-out-status` 查询。任务在Worker/D1后台推进，关闭页面继续；成功识别自动更新前台去程并保存旧值审计，包括之前人工去程标签。失败保留历史标记，回程不变。

国内探针必须同时符合国家和运营商ASN，实际城市以结果为准；无探针、终点无响应、证据不足都不伪造线路。通常需数分钟到十几分钟；不保证全部三网双栈有结果。选择VPS实际服务端口。安装验收ready不代表所有线路已测通。

公开入口不保存密钥。手动只用 --name 而未提供 --secret-stdin 时仍隐藏询问密钥；后台生成命令无需二次输入。完整流程针对Linux root/sudo，不在VPS引入Node/Python/Docker或新的常驻进程。

Windows诊断入口 `cf-route-out.ps1` 保留：ThreeNet默认只保存证据，-Publish仍保护人工锁及新任务结果；Local只代表当前宽带，不能代表三网，不自动上传。跨AI操作见 `cf-monitor-skill/SKILL.md`。

## 已有 VPS：一键刷新 / 自选菜单

安装新版后直接输入 `cfm` 即可打开下面的菜单。也可使用下载入口，已有辅助监控的VPS可直接执行，无需重装或输入密钥。**新增IPv6建议选1“全部刷新”**，它先重新识别网络和启用可用测点。

```bash
bash -c 'set -e; umask 077; f=$(mktemp); trap '\''rm -f -- "$f"'\'' EXIT; curl --noproxy "*" -fsSL --proto "=https" --proto-redir "=https" --connect-timeout 10 --max-time 90 --retry 1 https://raw.githubusercontent.com/checkzhh-afk/thintheme-earth/main/cf-refresh.sh -o "$f"; bash -n "$f"; bash "$f"'
```

菜单：1全部刷新；2网络配置；3谷歌送中；4三网回程；5提交三网去程；6查看状态；7更新辅助脚本与cfm；0退出。每次执行选择一项后退出。选1或5时询问去程TCP端口，回车默认80，可填写实际监听端口如443。

无需菜单、直接全部刷新：

```bash
bash -c 'set -e; umask 077; f=$(mktemp); trap '\''rm -f -- "$f"'\'' EXIT; curl --noproxy "*" -fsSL --proto "=https" --proto-redir "=https" --connect-timeout 10 --max-time 90 --retry 1 https://raw.githubusercontent.com/checkzhh-afk/thintheme-earth/main/cf-refresh.sh -o "$f"; bash -n "$f"; bash "$f" --all'
```

需要去程TCP443时，最后改为 `bash "$f" --all --port=443`。端口仅用于去程测量，不修改防火墙、服务或面板延迟探测协议。也支持 `--network / --google / --return / --outbound / --status / --update` 单项执行。

全部刷新执行：重新识别双栈网络并更新配置 → 双栈谷歌 → 双栈三网回程 → 提交双栈去程 → 验收。谷歌/回程绕过常规定时冷却，仍使用现有测点、分类和人工锁规则。配置失败就停止，其他失败会明确提示。入口串行加锁，沿用回程低内存保护，不新增常驻服务。刷新操作不升级代码；只有第7项/--update更新辅助脚本和菜单，现有Agent版本保留。

延迟、丢包等待Agent继续上报；三网去程在Worker后台测，成功识别自动更新面板，`cf-monitor route-out-status`查询进度。验收退出3表示尚未就绪，需看输出区分等Agent上报或其他问题；“已提交”和“验收通过”都不保证所有线路识别成功。没有辅助脚本时先运行上方安装/更新命令。


## 2026-11-21 能力保护与线路识别

- 已安装旧辅助脚本的 VPS，先执行公共 GitHub 的 cf-install.sh 一键更新，安装会自动创建 cfm，之后输入 cfm 选择刷新项目。cfm 默认菜单及 --all 只刷新数据；选7或 --update 才更新辅助脚本；直接 cf-route.sh run 只刷新回程。
- curl 的网络能力检查每族 connect=10秒、total=20秒；这是上限，成功即返回。任一族超时/无法确认记 unknown，禁止应用部分配置，保留原测点和公网IP。本地确实没有该族路由才记 unavailable；兼容只有IPv4或只有IPv6。
- 面板将旧 CUG 标签显示为 10099；仅AS10099不能当9929。识别到AS9929优先9929。ASN识别由Worker执行，Cymru失败时在原请求/时间预算内查询RIPEstat，证据写入classification。不能把旧hops重新提交伪装新测量。
- 自动回程无结果时保留上次成功线路，并显示“历史”；旧测量时间不变，失败时间和证据保存于last_attempt。成功新测量替换旧结果；人工锁继续保护。没有旧成功结果时显示未识别/无结果。
- 更新脚本不删除metrics、线路历史、节点身份、名称、流量或计费信息。重复应用相同有效配置不重置probes_since。确实改变测点/协议时，当前图表从新边界重新显示，避免混合不同测点样本；数据库历史未删除。
- 服务端修复不等于所有VPS已更新。使用doctor确认辅助脚本版本2026.11.21.1，再检查status/verify；等待Agent新上报和去程任务完成，不能将任务已提交写成测量成功。
