# VPS 双栈监控一键安装

此仓库的 `cf-install.sh` 是公开的轻量入口，下载并调用当前监控站的正式安装器。按名称自动注册由此入口完成，监控安装器与检测脚本仍统一由 Worker 提供。无需在 VPS 安装 Git。

监控站： https://cf-server-monitor.checkzhh.workers.dev

在每台 Linux VPS 执行以下完整一行（需要 Bash、curl，以及 root 或 sudo）：

```bash
bash -c 'set -e; umask 077; f=$(mktemp); trap '\''rm -f -- "$f"'\'' EXIT; curl --noproxy "*" -fsSL --proto "=https" --proto-redir "=https" --connect-timeout 10 --max-time 90 --retry 1 https://raw.githubusercontent.com/checkzhh-afk/thintheme-earth/main/cf-install.sh -o "$f"; bash -n "$f"; bash "$f"'
```

- 已有 Agent：自动复用原节点 ID 和密钥，安装双栈监控辅助功能。配置冲突时停止并提示，不强制覆盖。
- 新 VPS：推荐使用下面的 `NAME` 命令自动建号，无需先在后台创建节点。上方不带名称的旧命令仍支持手动输入后台已创建的 ID。
- 已成功安装的节点无需因网页布局更新而重装；每台 VPS 独立执行，不能在一台上替其他所有机器安装。
- IPv6 需要 VPS 自身具有可用 IPv6 网络；脚本不能代替服务商开通 IPv6。
- Google 送中以实际 3xx Location 跳转到 google.com.hk 或其子域判断，IPv4/IPv6 分开检测。

## 新 VPS：填写名称后自动接入

修改第一行的名称，将整段复制到 VPS 的 SSH 终端执行。API secret 会提示隐藏输入一次；不要把真实密钥写入公开命令或仓库。

```bash
(
  set -e
  NAME="my-vps-01"
  umask 077
  f=$(mktemp)
  trap 'rm -f -- "$f"' EXIT
  curl --noproxy '*' -fsSL --proto '=https' --proto-redir '=https' \
    --connect-timeout 10 --max-time 90 --retry 1 \
    https://raw.githubusercontent.com/checkzhh-afk/thintheme-earth/main/cf-install.sh -o "$f"
  bash -n "$f"
  bash "$f" --name="$NAME"
)
```

名称支持 1–100 个英文字母、数字、空格、点、下划线和连字符，首字符为字母或数字，例如 `LA-MINI-02`、`HK-01`。每台新 VPS 用不同名称；该参数不会重命名已有节点。

入口在新机下载并校验固定 v1.1.3 Agent，保存仅 root 可读的配置，由 Agent 真实上报自动注册，最多等待 120 秒拿到非空节点 ID，再执行正式低内存双栈安装和三项检查。已注册节点直接复用；本入口留下的待注册配置支持同名重跑，身份、密钥不被覆盖。`--name` 单独使用，不与手动 `--id` / `--secret-stdin` 等选项混用。

自动建号需要监控后台开启“自动发现”（本实例于 2026-11-21 已只读确认开启）。重名、密钥错误、网络失败或开关关闭时会停止并保留配置，请处理实际原因；不要删除配置反复建号。自定义路径或非 root 用户已有 Agent 应走原有配置复用流程。基础要求为 Bash、curl、flock、sha256sum、timeout，以及可运行的 systemd 或 cron；不新增常驻辅助进程。

## 安装后自动检查

一键入口自动依次执行以下三项，不需要安装后再手动输入：

1. `cf-monitor doctor`：检查依赖和可用内存。
2. `cf-monitor status`：读取监控状态。
3. `cf-monitor verify`：检查定时任务和数据上报是否就绪。

三项是轻量只读检查，不会重复进行线路测量，也不会增加常驻进程。检查期间某一项失败，仍会显示后续检查结果；最终输出中文说明，并保留失败退出码。正式安装器自身已有一次 verify，入口检查用于提供统一的三项结果和总结。

全部成功时显示“安装完成，三项检查全部通过，无需再手动执行检查命令”。尚未就绪时显示具体状态；安装冲突不会因为旧服务检查正常而被误报为成功。下载失败、安装器报错或尚未创建 cf-monitor 时会停止并提示原因。

`ready: true` 表示安装验收通过，不等于所有线路和探测槽均已有有效样本。上述三个命令仍可在日后排错时单独执行；等待上报后只需复查 verify，无需重新安装。

## 512MB VPS

使用现有 Agent 和 Bash/curl/ip/traceroute；不要求 Node、Python、Docker 或浏览器。Agent 每 20 秒串行探测；新机默认 HTTP/60 秒，旧机保留连接模式，auto 的实际频率跟随站点 WebSocket 配置；Google 每日检测，回程每 6 小时检测。systemd 辅助服务设置 MemoryMax=64M、CPUQuota=20%，这些限制不覆盖 Agent 和首次安装过程，不能当作整套监控实测峰值。

GitHub 仅提供入口；安装仍需要访问监控站和 Agent 下载地址。首次安装可能通过系统包管理器安装缺少的基础网络工具。此公开仓库不保存节点密钥。

## Windows 一键测去程（2026-11-21）

```powershell
$f=Join-Path $env:TEMP ('cf-route-out-'+[guid]::NewGuid().ToString('N')+'.ps1'); try { Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/checkzhh-afk/thintheme-earth/main/cf-route-out.ps1' -OutFile $f; & $f } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
```

默认选择面板节点并隐藏输入密钥，调用中国境内电信/联通/移动远端探针，分别测IPv4/IPv6 TCP80去程，结果保存当前目录。无可用探针则如实失败；默认不改手工线路。用 `-Publish` 更新未锁定线路。

本机宽带到VPS：把命令中 `& $f` 换成 `& $f -Mode Local -Target 'VPS公网IP' -Port 443`。本地tracert使用ICMP，另做TCP连接；只代表本机网络，不能代表全部三网，不自动上传。关闭VPN/TUN才能测原宽带出口。

跨AI规则见仓库 `cf-monitor-skill/SKILL.md`；项目权威源码位于CF-Server-Monitor/skills/cf-server-monitor-ops。
