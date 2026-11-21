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


# --name is handled here; the Worker installer remains the single monitoring bundle.
NODE_NAME=''
NAME_SET=0
FORWARD=()
for arg in "$@"; do
    case "$arg" in
        --name=*) NODE_NAME=${arg#*=}; NAME_SET=$((NAME_SET + 1)) ;;
        *) FORWARD+=("$arg") ;;
    esac
done
if [ "$NAME_SET" != 0 ]; then
    if [ "$NAME_SET" != 1 ] || [ "${#FORWARD[@]}" != 0 ] ||
       ! [[ "$NODE_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._\ -]{0,99}$ ]]; then
        echo 'Use --name="my-vps-01" alone (1-100 letters, digits, spaces, dots, underscores or hyphens).' >&2
        exit 2
    fi
    config_hint=${CF_PROBE_CONFIG:-${CF_ROUTE_CONFIG:-}}
    if [ -n "$config_hint" ] && [ "$config_hint" != /etc/config/cf-probe/config.conf ]; then
        echo 'For a custom Agent config, use the entry without --name.' >&2; exit 2
    fi
    if [ "$(id -u)" != 0 ] && [ -e "${HOME:-/root}/.cf-probe/config.conf" ]; then
        echo 'An existing user Agent needs to be reused explicitly; no root Agent was created.' >&2; exit 2
    fi
    # Re-enter before reading credentials; sudo need not preserve environment variables.
    if [ "$(id -u)" != 0 ]; then exec sudo bash "$0" "--name=$NODE_NAME"; fi
fi

register_named_node() (
    set -euo pipefail
    local_config=/etc/config/cf-probe/config.conf
    pending=/etc/config/cf-probe/.cf-monitor-register-pending
    endpoint=https://cf-server-monitor.checkzhh.workers.dev/update
    config_value() {
        local key value result=''
        while IFS='=' read -r key value || [ -n "${key:-}" ]; do
            value=${value%$'\r'}; value=${value#\"}; value=${value%\"}
            [ "$key" != "$1" ] || result=$value
        done < "$local_config"
        printf '%s' "$result"
    }
    if [ -r /etc/cf-monitor/runtime.conf ]; then
        while IFS='=' read -r key value || [ -n "${key:-}" ]; do
            if [ "$key" = CF_PROBE_CONFIG ] && [ -n "$value" ] && [ "$value" != "$local_config" ]; then
                echo 'For a custom runtime config, use the entry without --name.' >&2; exit 2
            fi
        done < /etc/cf-monitor/runtime.conf
    fi
    for tool in flock sha256sum timeout; do
        command -v "$tool" >/dev/null || { echo "Install $tool first, then retry." >&2; exit 2; }
    done
    mkdir -p /run/lock
    exec 8>/run/lock/cf-monitor-install.flock
    flock -n 8 || { echo 'Another installation is running.' >&2; exit 75; }
    if [ -e "$local_config" ]; then
        [ -f "$local_config" ] && [ ! -L "$local_config" ] || { echo 'Invalid Agent config path.' >&2; exit 2; }
        node_id=$(config_value SERVER_ID)
        if [ -n "$node_id" ]; then
            echo 'Existing node found; keeping its identity and name.' >&2
            exit 0
        fi
        if [ ! -f "$pending" ] || [ "$(config_value NAME)" != "$NODE_NAME" ] ||
           [ "$(config_value WORKER_URL)" != "$endpoint" ]; then
            echo 'Existing unfinished Agent config differs; it was not overwritten.' >&2; exit 2
        fi
        echo 'Resuming unfinished registration with the existing config.' >&2
    else
        # Never create a second identity beside an installation we cannot safely reuse.
        if command -v cf-probe >/dev/null || [ -e /etc/cf-monitor/runtime.conf ] ||
           [ -n "${CF_PROBE_CONFIG:-${CF_ROUTE_CONFIG:-}}" ] ||
           [ -e "${HOME:-/root}/.cf-probe/config.conf" ] || [ -e /data/config.conf ] ||
           [ -e /etc/cf-probe.conf ]; then
            echo 'Nonstandard existing Agent found; run this entry without --name to reuse it.' >&2; exit 2
        fi
    fi
    if ! { command -v systemctl >/dev/null && [ -d /run/systemd/system ]; } &&
       ! { command -v crontab >/dev/null && { pgrep -x cron >/dev/null || pgrep -x crond >/dev/null; }; }; then
        echo 'Enable systemd or cron before installing.' >&2; exit 2
    fi
    case "$(uname -m)" in
        x86_64|amd64) arch=amd64; expected=711326c3f2d7e41919e0922d8dcc12d694df95c92a3b5db4098c9742c632d405 ;;
        aarch64|arm64) arch=arm64; expected=82a7815a047053ed6ad5557d6499ad05e14f5335dae7cbaf8df62211743adbe0 ;;
        i386|i686) arch=386; expected=72af0e2beba63a0c4bf97a02188ffaeb18224b23e3917bec79e1db296b6d552a ;;
        *) echo 'Unsupported Agent architecture.' >&2; exit 2 ;;
    esac
    registration_tmp=$(mktemp -d)
    staging_config=''
    trap 'rm -rf -- "$registration_tmp"; [ -z "$staging_config" ] || rm -f -- "$staging_config"' EXIT
    curl --noproxy '*' -fsSL --proto '=https' --proto-redir '=https' \
        --connect-timeout 10 --max-time 90 --retry 1 -A cfsm \
        "https://github.com/huilang-me/cfsm-agent/releases/download/v1.1.3/cf-probe-linux-$arch" \
        -o "$registration_tmp/cf-probe"
    printf '%s  %s\n' "$expected" "$registration_tmp/cf-probe" | sha256sum -c - >/dev/null
    chmod 700 "$registration_tmp/cf-probe"
    if [ ! -e "$local_config" ]; then
        if ! { exec 7<> /dev/tty; } 2>/dev/null; then
            echo 'A terminal is required to enter the API secret. Run the command in an SSH terminal.' >&2; exit 2
        fi
        printf 'API secret (hidden): ' >&2
        IFS= read -rs registration_secret <&7 || { printf '\nSecret input cancelled.\n' >&2; exit 2; }
        printf '\n' >&2
        exec 7>&-
        if [ -z "$registration_secret" ] || [[ "$registration_secret" == *[[:cntrl:]]* || "$registration_secret" == *'"'* || "$registration_secret" == *'\'* ]]; then
            echo 'Invalid API secret.' >&2; exit 2
        fi
        mkdir -p /etc/config/cf-probe
        printf 'SERVER_ID=""\nSECRET="%s"\nWORKER_URL="%s"\nNAME="%s"\n' "$registration_secret" "$endpoint" "$NODE_NAME" > "$registration_tmp/config.conf"
        printf 'COLLECT_INTERVAL="0"\nREPORT_INTERVAL="60"\nCONNECTION_MODE="http"\nPING_MODE="icmp"\nUA="cfsm"\nAUTO_UPDATE="0"\nCONFIG_MD5="none"\n' >> "$registration_tmp/config.conf"
        for slot in CT_NODE CU_NODE CM_NODE BD_NODE NODE_1 NODE_2 NODE_3 NODE_4; do
            printf '%s="0"\n' "$slot" >> "$registration_tmp/config.conf"
        done
        unset registration_secret
        # Publish a complete config atomically without replacing an existing file.
        staging_config=$(mktemp /etc/config/cf-probe/.register.XXXXXXXX)
        cat "$registration_tmp/config.conf" > "$staging_config"
        chmod 600 "$staging_config"
        : > "$pending"
        if ! ln "$staging_config" "$local_config"; then rm -f -- "$staging_config"; exit 2; fi
        rm -f -- "$staging_config"
    fi
    # Agent reads the root-only config itself: no secret in argv or shell sourcing.
    timeout -k 5 90 "$registration_tmp/cf-probe" install 8>&-
    printf 'Waiting for the Agent to register "%s" (up to 120 seconds)...\n' "$NODE_NAME"
    for ((attempt=0; attempt<60; attempt++)); do
        node_id=$(config_value SERVER_ID)
        if [[ "$node_id" =~ ^[a-zA-Z0-9_-]{1,128}$ ]]; then
            rm -f -- "$pending"
            printf 'Registered node: %s\n' "$node_id"
            exit 0
        fi
        sleep 2
    done
    echo 'Registration pending/failed. Check auto-discovery, API secret, network and duplicate names. Config was retained; fix the cause and rerun with the same name. Do not delete the config.' >&2
    exit 3
)

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
if [ "$NAME_SET" = 1 ]; then register_named_node; fi
install_rc=0
as_root bash "$CF_INSTALL" --url='https://cf-server-monitor.checkzhh.workers.dev' "${FORWARD[@]}" || install_rc=$?
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
