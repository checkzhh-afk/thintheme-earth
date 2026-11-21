#!/usr/bin/env bash
# CF Monitor menu: refresh measurements or explicitly update the helper bundle.
set +x
set -uo pipefail
umask 077

usage() {
    cat <<'HELP'
用法：bash cf-refresh.sh [--menu|--all|--network|--google|--return|--outbound|--status|--update] [--port=80]
默认打开菜单；--all 无需交互，刷新双栈配置、谷歌、回程并提交双栈去程。
--port 只用于去程任务，填写 VPS 实际监听的 TCP 端口，默认 80。
--network 只刷新网络配置；--google/--return 使用已有配置检测双栈。
--status 查看依赖、验收及去程任务状态，不触发测量。
--update 更新辅助脚本和 cfm 菜单并自动验收；保留现有 Agent，不升级 Agent 版本。
退出码：0 操作完成；1 部分步骤失败；2 用法/依赖错误；3 等待验收；75 有任务运行或低内存暂缓。
HELP
}

ACTION=menu
PORT=80
PORT_SET=0
ACTION_SET=0
for arg in "$@"; do
    case "$arg" in
        --menu|--all|--network|--google|--return|--outbound|--status|--update)
            [ "$ACTION_SET" = 0 ] || { echo '一次只能选择一种操作。' >&2; exit 2; }
            ACTION=${arg#--}; ACTION_SET=1 ;;
        --port=*) PORT=${arg#*=}; PORT_SET=1 ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
valid_port() { [[ "$1" =~ ^[1-9][0-9]{0,4}$ ]] && [ "$1" -le 65535 ]; }
valid_port "$PORT" || { echo 'TCP 端口必须为 1 到 65535。' >&2; exit 2; }
[ "$(uname -s)" = Linux ] || { echo '请在已安装 CF Monitor 的 Linux VPS 上执行。' >&2; exit 2; }
if [ "$(id -u)" != 0 ]; then
    command -v sudo >/dev/null || { echo '请使用 root，或先安装 sudo。' >&2; exit 2; }
    exec sudo bash "${BASH_SOURCE[0]}" "$@"
fi
trap 'exit 130' INT
trap 'exit 143' TERM

ask_port() {
    local input
    [ "$PORT_SET" = 0 ] || return 0
    printf '去程测试 TCP 端口 [80，填写 VPS 实际监听端口]：'
    IFS= read -r input || { echo '未读到端口；已取消。' >&2; return 2; }
    PORT=${input:-80}
    valid_port "$PORT" || { echo '端口无效；已取消。' >&2; return 2; }
}
if [ "$ACTION" = menu ]; then
    cat <<'MENU'

CF Monitor 管理菜单（IPv4 + IPv6）
  1) 全部刷新（网络配置 → 谷歌 → 回程 → 提交去程 → 验收）
  2) 只刷新网络配置（新增 IPv6 / 公网 IP 变化时使用）
  3) 只重新检测谷歌送中
  4) 只重新检测三网回程（VPS → 中国）
  5) 只提交三网去程（中国 → VPS）
  6) 查看依赖、验收和去程进度
  7) 更新辅助脚本和 cfm 菜单（保留现有 Agent）
  0) 退出
MENU
    printf '选择 [0-7]：'
    IFS= read -r choice || { echo '未读到选择；已取消。自动运行请用 --all。' >&2; exit 2; }
    case "$choice" in
        1) ACTION=all; ask_port || exit $? ;;
        2) ACTION=network ;;
        3) ACTION=google ;;
        4) ACTION=return ;;
        5) ACTION=outbound; ask_port || exit $? ;;
        6) ACTION=status ;;
        7) ACTION=update ;;
        0) exit 0 ;;
        *) echo '选择无效；已取消。' >&2; exit 2 ;;
    esac
fi

# Pin the installed release for this invocation; the credentials remain in its config.
REFRESH_DIR=${CF_REFRESH_DIR:-/usr/local/lib/cf-monitor/current}
REFRESH_DIR=$(CDPATH= cd -P -- "$REFRESH_DIR" 2>/dev/null && pwd) || {
    echo '未找到辅助监控脚本，请先运行现有的一键安装/更新命令 cf-install.sh。' >&2; exit 2;
}
[ -r "$REFRESH_DIR/cf-monitor" ] || { echo '缺少 cf-monitor，请先更新辅助监控脚本。' >&2; exit 2; }
for script in cf-google.sh cf-route.sh; do
    if [ "$ACTION" = all ] || { [ "$ACTION" = google ] && [ "$script" = cf-google.sh ]; } || { [ "$ACTION" = return ] && [ "$script" = cf-route.sh ]; }; then
        [ -r "$REFRESH_DIR/$script" ] || { echo "缺少 $script，请先更新辅助监控脚本。" >&2; exit 2; }
    fi
done
# Do not inherit a caller's lock bypass.
unset CF_LOCK_HELD
# Updating uses the current node's Worker and config, never registration credentials.
# Run before acquiring the refresh lock or lowering limits: the installer owns its
# install lock and diagnostics. It must not inherit the measurement memory limit.
update_bundle() (
    set -euo pipefail
    [ -r "$REFRESH_DIR/cf-common.sh" ] || { echo '缺少 cf-common.sh，请运行公共一键安装/更新命令。' >&2; exit 2; }
    source "$REFRESH_DIR/cf-common.sh"
    cf_temp
    cf_read_config
    [[ "$CF_API" =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?$ ]] || { echo '配置中的 Worker 地址无效。' >&2; exit 2; }
    export CF_PROBE_CONFIG="$CONFIG_FILE"
    echo '更新辅助脚本与 cfm 菜单；自动执行安装检查。'
    curl --noproxy '*' -fsSL --proto '=https' --proto-redir '=https' \
        --connect-timeout 10 --max-time 90 --retry 1 -A "$UA" \
        "$CF_API/files/cf-install.sh" -o "$CF_TMP/cf-install.sh"
    bash -n "$CF_TMP/cf-install.sh"
    bash "$CF_TMP/cf-install.sh" "--url=$CF_API"
)
if [ "$ACTION" = update ]; then
    update_bundle
    exit $?
fi
# No permanent helper. The existing scripts retain their timer lock, timeouts,
# route memory guard and serial probes.
ulimit -v 131072 2>/dev/null || true
if command -v renice >/dev/null; then renice -n 15 -p "$$" >/dev/null 2>&1 || true; fi
if [ "$ACTION" != status ]; then
    command -v flock >/dev/null || { echo '缺少 flock，请先运行一键更新命令。' >&2; exit 2; }
    REFRESH_LOCK_DIR=${CF_LOCK_DIR:-/run/lock}
    mkdir -p "$REFRESH_LOCK_DIR" || exit 1
    exec 8>"$REFRESH_LOCK_DIR/cf-refresh.flock" || exit 1
    flock -n 8 || { echo '已有刷新任务运行，请稍后再试。' >&2; exit 75; }
fi

FAILED=0
DEFERRED=0
PENDING=0
step() {
    local title=$1 rc
    shift
    printf '\n=== %s ===\n' "$title"
    "$@"
    rc=$?
    printf '\n'
    case "$rc" in
        0) ;;
        75) DEFERRED=1; echo '本项暂缓：任务锁忙或可用内存不足。' >&2 ;;
        *) FAILED=1; printf '本项未完成，退出码 %s。\n' "$rc" >&2 ;;
    esac
    return "$rc"
}
verify() {
    local rc
    printf '\n=== 查看配置与上报验收 ===\n'
    bash "$REFRESH_DIR/cf-monitor" verify
    rc=$?
    printf '\n'
    case "$rc" in
        0) echo '验收通过；这不代表每条线路都已识别或每个测点都可达。' ;;
        3) PENDING=1; echo '验收未就绪：若 reported_after_apply=false，需等 Agent 下一次上报；其他原因见上方输出。无需立即重复全部刷新。' ;;
        *) FAILED=1; echo "验收查询失败，退出码 $rc。" >&2 ;;
    esac
}
network() {
    step '重新识别 IPv4/IPv6 并更新探测配置' bash "$REFRESH_DIR/cf-monitor" apply
    local rc=$?
    [ "$rc" = 0 ] || return "$rc"
    echo '配置已刷新。延迟、丢包由 Agent 后续采集上报；新增 IPv6 应在状态中显示 available。'
}
google() { step '立即检测并上报双栈谷歌 HK 跳转结果' bash "$REFRESH_DIR/cf-google.sh" run; }
routes() {
    step '立即检测并上报三网回程（串行，可能需要数分钟）' bash "$REFRESH_DIR/cf-route.sh" run
    local rc=$?
    [ "$rc" = 0 ] || return "$rc"
    echo '回程脚本执行完成；禁用测点会跳过，线路识别及人工锁定结果以面板为准。'
}
outbound() {
    step "提交双栈三网去程任务（TCP $PORT）" bash "$REFRESH_DIR/cf-monitor" route-out both "$PORT"
    local rc=$?
    [ "$rc" = 0 ] || return "$rc"
    echo '已提交/复用后台任务，尚不代表测量成功。成功识别后自动更新面板；用 cf-monitor route-out-status 查看进度。'
}
case "$ACTION" in
    all)
        network || { rc=$?; echo '配置刷新未完成，已停止后续检测。' >&2; exit "$rc"; }
        google || true
        routes || true
        outbound || true
        verify ;;
    network) network || exit $?; verify ;;
    google) google || exit $? ;;
    return) routes || exit $? ;;
    outbound) outbound || exit $? ;;
    status)
        step '依赖与可用内存' bash "$REFRESH_DIR/cf-monitor" doctor || true
        verify
        step '三网去程任务进度' bash "$REFRESH_DIR/cf-monitor" route-out-status || true ;;
esac
[ "$FAILED" = 0 ] || { echo '部分步骤未完成，请根据上方错误重试对应单项。' >&2; exit 1; }
[ "$DEFERRED" = 0 ] || exit 75
[ "$PENDING" = 0 ] || exit 3
printf '\n所选操作已执行。谷歌/线路识别以实际上报为准；去程任务和 Agent 新样本可能仍在等待中。\n'
