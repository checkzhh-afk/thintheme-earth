---
name: cf-monitor-remote-ops
description: 跨AI操作本实例的VPS监控安装、IPv4/IPv6三网去程测量与证据交接；不代替国内实际测点，不推测被墙或线路等级。
---

# CF Monitor 跨AI操作

这是公开操作入口，适用于 Codex、Claude Code、OpenCode。若可访问开发工作区，先读取 CF-Server-Monitor/skills/cf-server-monitor-ops/SKILL.md 及 references/outbound-and-dns.md，那里是完整开发与部署规则。公开包仅提供操作流程，不含凭据或生产备份。

## 实例与约束

- 监控站 https://cf-server-monitor.checkzhh.workers.dev 。GitHub仓库 checkzhh-afk/thintheme-earth。
- 用户多数VPS仅512MB；不SSH，不在VPS装Node/Python/Docker或另加常驻进程。VPS命令交给用户执行。
- 沿用用户当前授权；询问尚缺的具体目标/参数，不重复确认已授权操作。不猜密钥。
- 去程 out 是中国或本机到VPS；回程 in 是VPS到中国。面板TCP延迟是VPS出站测试，不代表国内入站可达性或带宽。
- Google送中仅按真实HTTP重定向google.com.hk判定；IPv4/IPv6独立，失败不能当正常。
- 保留身份、名字、计费、流量、原界面和回程。显式去程任务成功后按用户授权更新旧去程（包括人工锁），保留审计；任务开始后新人工修改优先。失败/未知保留历史，禁止另行批量解锁。

## 推荐：后台或VPS一键提交

新VPS：登录监控后台 → 自动添加（需开启自动发现）→ Linux / 当前用户（root或sudo）→ 填名称 → 复制完整命令执行。认证通过stdin传入，无需再输入密钥；复制命令不要公开。已有VPS：执行仓库cf-install.sh，无需名称和密钥，复用现有配置。安装自动提交双栈TCP80去程任务，自动doctor/status/verify一次。

后台节点列表点击🌐“检测三网去程”；或VPS执行 `cf-monitor route-out`、`cf-monitor route-out ipv4 443`。查看进度用 `cf-monitor route-out-status`。任务保存在Worker/D1，关闭页面继续，重复提交复用活跃任务。通常数分钟到十几分钟，不保证三网或IPv6探针都有供应。VPS不增加常驻进程。

成功必须有中国境内指定运营商来源、目标匹配、TCP端口匹配、终点回应和可识别hop证据。成功自动更新前台去程并保留旧值审计；无结果保留历史并标记“历史”。安装验收ready和去程完成分开。

## Windows一键去程（兼容诊断）

下载仓库根目录 cf-route-out.ps1 到唯一临时文件，下载成功后执行，finally清理。入口验证Worker正式脚本的SHA256，不跳过校验。

```powershell
$f=Join-Path $env:TEMP ('cf-route-out-'+[guid]::NewGuid().ToString('N')+'.ps1'); try { Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/checkzhh-afk/thintheme-earth/main/cf-route-out.ps1' -OutFile $f; & $f } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
```

默认ThreeNet模式：选节点、隐藏输入API密钥、串行调用中国境内电信/联通/移动远端探针。IPv4/IPv6最多6项，默认TCP80。当前宽带仅发送任务，并不是三网测量来源。ASN和国家都需匹配，实际城市以结果为准，没有探针就报告不可用。目标应有对应监听端口；需要可加-Port 443。首次完整测量可能数分钟。

- 预览：在执行位置使用 `& $f -Plan`。
- 明确节点：`& $f -ServerId '<id>' -Family ipv4 -Port 443`。
- 本地当前宽带：`& $f -Mode Local -Target '<VPS公网IP>' -Port 443`。关闭VPN/TUN以测原宽带。只代表一个来源运营商；IPv4/IPv6各传一个IP。
- 默认仅保存证据。`-Publish`才写回未锁线路；人工锁保持不变。用户明确要求人工覆盖时先展示具体节点、运营商、族、新旧标签及真实hop证据。

Local用Windows自带ICMP tracert，另作TCP端口连接，不是TCP traceroute。星号/拒绝连接不证明被墙。所有结果保存当前目录cf-route-results-*/results.json；文件可能含IP，不公开上传。

脚本支持进程环境CF_MONITOR_API_SECRET，否则隐藏输入。密钥仅放X-API-Secret请求头，不进URL、argv、GitHub或日志。不要输出配置文件或环境变量。

## VPS与DNS

原Linux一键入口cf-install.sh保持可用，--name用于新机命名；已有Agent复用ID和名称。安装自动doctor/status/verify，ready只代表配置及近期上报，不能说所有测点都通。

安装保留旧机connection_mode和ping_mode，新机默认HTTP/TCP；auto可能按站点设置使用更频繁的WebSocket上报，不宣传更省内存。DNS按族解析，IPv4只用A、IPv6只用AAAA，Worker每15分钟最多刷1节点、各节点至少6小时间隔。DNS失败保留旧IP；手工IP不自动改；全局域名来源可跟随全局设置。测点真正变化后等待120秒历史边界，不能把旧协议或旧测点样本当新测量。


## 已有 VPS：全部刷新或菜单选择

新版安装/更新自动创建 `cfm`，无需第二条命令。直接输入 `cfm` 打开菜单，`cfm --update` 或第7项更新辅助脚本与菜单，保留现有Agent版本；`cfm --status`查看状态。也可使用仓库根目录 `cf-refresh.sh`，具体下载命令见 [操作说明](../README-CF-MONITOR.md)。无参数打开菜单：1全部刷新、2网络配置、3谷歌、4回程、5去程、6状态、7更新辅助脚本与cfm、0退出。`--all` 无交互；`--port=443` 可指定去程TCP端口，默认80，菜单选全部/去程时会询问。其他CLI参数：`--network / --google / --return / --outbound / --status / --update`。

全部刷新顺序：重新识别IPv4/IPv6与公网IP并apply → 立即测双栈谷歌 → 立即测双栈回程 → 提交双栈三网去程 → verify。新增IPv6优先选全部刷新；单独cf-route.sh run不会启用禁用槽，cf-monitor run会受每日/6小时冷却限制。仅想重测回程可选4，沿用原API的分类与人工锁规则。

入口复用已安装脚本和本机凭据，不升级/重装Agent；配置失败停止，其他步骤失败显示对应状态。串行、加锁、回程低内存保护，无新增常驻进程。没有辅助脚本或旧版本缺少去程接口时先用cf-install.sh更新。用户在VPS执行，AI不SSH。

延迟/丢包等待Agent新样本；去程“已提交”不等于成功，使用cf-monitor route-out-status查进度，成功识别自动更新面板。verify退出3结合输出区分等上报与其他未就绪，不无限重跑；0也不代表所有测点可达或每条线路都识别。当前只提供实测入口，不能宣称已在用户VPS执行。

## 交接

记录执行命令（去除凭据）、节点/族/来源/协议/端口、真实城市与ASN、measurement_id/hops、结果路径、是否上传及updated数量。checked=0或updated=0不能声称写回成功。模拟结果、真实本机测试、真实远端三网测试分别标明。失败保留证据并说明缺什么，不编造CN2/9929/CMIN2或北京三网。


## 2026-11-21 能力保护与线路识别

- 已安装旧辅助脚本的 VPS，先执行公共 GitHub 的 cf-install.sh 一键更新，安装会自动创建 cfm，之后输入 cfm 选择刷新项目。cfm 默认菜单及 --all 只刷新数据；选7或 --update 才更新辅助脚本；直接 cf-route.sh run 只刷新回程。
- curl 的网络能力检查每族 connect=10秒、total=20秒；这是上限，成功即返回。任一族超时/无法确认记 unknown，禁止应用部分配置，保留原测点和公网IP。本地确实没有该族路由才记 unavailable；兼容只有IPv4或只有IPv6。
- 面板将旧 CUG 标签显示为 10099；仅AS10099不能当9929。识别到AS9929优先9929。ASN识别由Worker执行，Cymru失败时在原请求/时间预算内查询RIPEstat，证据写入classification。不能把旧hops重新提交伪装新测量。
- 自动回程无结果时保留上次成功线路，并显示“历史”；旧测量时间不变，失败时间和证据保存于last_attempt。成功新测量替换旧结果；人工锁继续保护。没有旧成功结果时显示未识别/无结果。
- 更新脚本不删除metrics、线路历史、节点身份、名称、流量或计费信息。重复应用相同有效配置不重置probes_since。确实改变测点/协议时，当前图表从新边界重新显示，避免混合不同测点样本；数据库历史未删除。
- 服务端修复不等于所有VPS已更新。使用doctor确认辅助脚本版本2026.11.22.1，再检查status/verify；等待Agent新上报和去程任务完成，不能将任务已提交写成测量成功。

安装器已修复 traceroute 的 `-N` 功能检查在 `pipefail` 下因提前关闭管道而误报的问题。遇到旧版 `A full traceroute with -N support is required.` 时重新运行公共 GitHub 安装命令；不要删除 Agent 配置或跳过依赖检查。真正不支持 `-N` 时仍自动安装系统 traceroute 包并重新检查，失败则在节点配置变更前停止。


## 2026-11-22 回程识别与终端反馈修复

辅助版本 `2026.11.22.1`。修复 Worker ASN 查询使用不受 workerd 支持的 `redirect:error` 导致查询在发送前失败的问题，改为 `manual` 并将非 2xx 转入备用来源，不跟随跳转。请求数、超时和 VPS 串行低内存策略不变。

已有 VPS 输入 `cfm --update` 更新辅助脚本与菜单；成功后执行 `cfm --return` 或菜单 4，重新测量双栈三网回程。只想立即重测也可直接 `cfm --return`：服务端修复发布后即生效，旧客户端仍兼容，但没有新版逐项提示。不要把旧 hops 再上传并改时间冒充新测量。

逐项反馈：
- `已更新：线路`：本次识别已写入面板。
- `ASN 查询失败，保留历史：线路` / `尚未识别线路，保留历史：线路`：本次无有效识别，显示旧成功结果与旧时间；“历史”是保留真实证据，不是更新程序失败。
- `人工锁定，保留：线路`：自动结果没有覆盖人工值，不要自动解锁。
- `未采到有效路由跳点` / `尚未识别线路`：没有可用的新识别。
- `已有更新的结果`：本次未覆盖较新记录。
- `服务端未返回识别详情`：旧 API 兼容提示，只能确认提交，不能宣称识别成功。

更新后的安装验收退出 3 时先看具体原因：若仅等 Agent 上报，辅助版本已切换到 `2026.11.22.1`、原网络配置有效，可以单独执行 `cfm --return`；其他错误按输出处理。不要用 `|| true` 吞掉更新错误并宣称成功。菜单 4 只重测回程，不提交去程任务，也不清空旧记录。API 保留原字段，并新增 `results`（outcome / measured_label / display_label / reason）。
