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

新VPS：登录监控后台 → 自动发现 → Linux / 当前用户（root或sudo）→ 填名称 → 复制完整命令执行。认证通过stdin传入，无需再输入密钥；复制命令不要公开。已有VPS：执行仓库cf-install.sh，无需名称和密钥，复用现有配置。安装自动提交双栈TCP80去程任务，自动doctor/status/verify一次。

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

## 交接

记录执行命令（去除凭据）、节点/族/来源/协议/端口、真实城市与ASN、measurement_id/hops、结果路径、是否上传及updated数量。checked=0或updated=0不能声称写回成功。模拟结果、真实本机测试、真实远端三网测试分别标明。失败保留证据并说明缺什么，不编造CN2/9929/CMIN2或北京三网。
