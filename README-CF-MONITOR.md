# VPS 双栈监控一键安装

此仓库的 `cf-install.sh` 是公开的轻量入口，下载并调用当前监控站的正式安装器。安装器与检测脚本仍统一由 Worker 提供，不在此复制维护。无需在 VPS 安装 Git。

监控站： https://cf-server-monitor.checkzhh.workers.dev

在每台 Linux VPS 执行以下完整一行（需要 Bash、curl，以及 root 或 sudo）：

```bash
bash -c 'set -e; umask 077; f=$(mktemp); trap '\''rm -f -- "$f"'\'' EXIT; curl --noproxy "*" -fsSL --proto "=https" --proto-redir "=https" --connect-timeout 10 --max-time 90 --retry 1 https://raw.githubusercontent.com/checkzhh-afk/thintheme-earth/main/cf-install.sh -o "$f"; bash -n "$f"; bash "$f"'
```

- 已有 Agent：自动复用原节点 ID 和密钥，安装双栈监控辅助功能。配置冲突时停止并提示，不强制覆盖。
- 新 VPS：先在监控后台创建节点，再执行命令；按终端提示输入节点 ID 和 API secret，密钥输入不回显。
- 已成功安装的节点无需因网页布局更新而重装；每台 VPS 独立执行，不能在一台上替其他所有机器安装。
- IPv6 需要 VPS 自身具有可用 IPv6 网络；脚本不能代替服务商开通 IPv6。
- Google 送中以实际 3xx Location 跳转到 google.com.hk 或其子域判断，IPv4/IPv6 分开检测。

## 安装后自动检查

一键入口自动依次执行以下三项，不需要安装后再手动输入：

1. `cf-monitor doctor`：检查依赖和可用内存。
2. `cf-monitor status`：读取监控状态。
3. `cf-monitor verify`：检查定时任务和数据上报是否就绪。

三项是轻量只读检查，不会重复进行线路测量，也不会增加常驻进程。检查期间某一项失败，仍会显示后续检查结果；最终输出中文说明，并保留失败退出码。正式安装器自身已有一次 verify，入口检查用于提供统一的三项结果和总结。

全部成功时显示“安装完成，三项检查全部通过，无需再手动执行检查命令”。尚未就绪时显示具体状态；安装冲突不会因为旧服务检查正常而被误报为成功。下载失败、安装器报错或尚未创建 cf-monitor 时会停止并提示原因。

`ready: true` 表示安装验收通过，不等于所有线路和探测槽均已有有效样本。上述三个命令仍可在日后排错时单独执行；等待上报后只需复查 verify，无需重新安装。

## 512MB VPS

使用现有 Agent 和 Bash/curl/ip/traceroute；不要求 Node、Python、Docker 或浏览器。Agent 每 20 秒串行探测、每 60 秒 HTTP 上报；Google 每日检测，回程每 6 小时检测。systemd 辅助服务设置 MemoryMax=64M、CPUQuota=20%，这些限制不覆盖 Agent 和首次安装过程，不能当作整套监控实测峰值。

GitHub 仅提供入口；安装仍需要访问监控站和 Agent 下载地址。首次安装可能通过系统包管理器安装缺少的基础网络工具。此公开仓库不保存节点密钥。
