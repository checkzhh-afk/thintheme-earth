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
if [ "$(id -u)" = 0 ]; then
    bash "$CF_INSTALL" --url='https://cf-server-monitor.checkzhh.workers.dev' "$@"
else
    sudo bash "$CF_INSTALL" --url='https://cf-server-monitor.checkzhh.workers.dev' "$@"
fi
