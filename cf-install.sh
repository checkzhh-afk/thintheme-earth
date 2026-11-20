#!/usr/bin/env bash
# Public entry point; credentials are read by the installer on the VPS.
set +x
set -euo pipefail
umask 077

if [ "$(uname -s)" != Linux ]; then
    echo 'Run this command on the Linux VPS.' >&2
    exit 2
fi
command -v curl >/dev/null || { echo 'Install curl first, then retry.' >&2; exit 2; }
if [ "$(id -u)" != 0 ]; then
    command -v sudo >/dev/null || { echo 'Run as root, or install sudo first.' >&2; exit 2; }
fi

CF_INSTALL=$(mktemp)
trap 'rm -f -- "$CF_INSTALL"' EXIT
curl --noproxy '*' -fsSL \
    --proto '=https' --proto-redir '=https' \
    --connect-timeout 10 --max-time 90 --retry 1 -A cfsm \
    'https://cf-server-monitor.checkzhh.workers.dev/files/cf-install.sh' \
    -o "$CF_INSTALL"
bash -n "$CF_INSTALL"
# Keep failures visible while running lightweight post-install diagnostics.
as_root() {
    if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi
}
install_rc=0
as_root bash "$CF_INSTALL" --url='https://cf-server-monitor.checkzhh.workers.dev' "$@" || install_rc=$?
if [ "$install_rc" != 0 ] && [ "$install_rc" != 3 ]; then
    printf '\n安装未完成（退出码 %s），请查看上方错误。\n' "$install_rc" >&2
    exit "$install_rc"
fi

# Exit 3 can mean a plan conflict OR pending verification. Never turn it into
# success just because an older installed service still passes its checks.
monitor_path=$(as_root bash -c 'command -v cf-monitor' || true)
if [ -z "$monitor_path" ]; then
    printf '\n安装未完成：尚未找到 cf-monitor，请查看上方冲突或错误。\n' >&2
    if [ "$install_rc" != 0 ]; then exit "$install_rc"; else exit 1; fi
fi

check_rc=0
verify_rc=0
for action in doctor status verify; do
    case "$action" in
        doctor) printf '\n[1/3] 检查依赖与可用内存\n' ;;
        status) printf '\n[2/3] 读取监控状态\n' ;;
        verify) printf '\n[3/3] 验证定时任务与数据上报\n' ;;
    esac
    rc=0
    as_root "$monitor_path" "$action" || rc=$?
    printf '\n'
    if [ "$action" = verify ]; then verify_rc=$rc; fi
    if [ "$rc" != 0 ] && [ "$check_rc" = 0 ]; then check_rc=$rc; fi
done
if [ "$install_rc" != 0 ]; then
    printf '本次安装尚未通过验收（退出码 %s）。三项检查已自动执行，请查看上方冲突或未就绪原因。\n' "$install_rc" >&2
    exit "$install_rc"
elif [ "$check_rc" = 0 ]; then
    printf '安装完成，三项检查全部通过，无需再手动执行检查命令。\n'
elif [ "$check_rc" = 3 ] && [ "$verify_rc" = 3 ]; then
    printf '安装已完成，但监控尚未就绪；请查看上方定时任务或数据上报状态。\n' >&2
    exit 3
else
    printf '安装流程已完成，但检查未全部通过（退出码 %s），请查看上方结果。\n' "$check_rc" >&2
    exit "$check_rc"
fi
