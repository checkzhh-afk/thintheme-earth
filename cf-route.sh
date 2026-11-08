#!/bin/sh
# cf-route.sh - detect three-carrier return routes and report them to CF-Server-Monitor.
#
# Usage:
#   cf-route              run once and upload
#   cf-route install      install to /usr/local/bin + cron every 6h, then run once
#   cf-route uninstall    remove cron entry and installed script
#
# Reads SERVER_ID / SECRET / WORKER_URL from the cf-probe config file.

set -u

BIN=/usr/local/bin/backtrace-cfsm
CRON_TAG=/usr/local/bin/cf-route
API_PATH=/api/route
CF_ROUTE_CONFIG=${CF_ROUTE_CONFIG:-}
CF_ROUTE_REFRESH=${CF_ROUTE_REFRESH:-0}
TMP_JSON=${TMPDIR:-/tmp}/cf-route-report.$$
TMP_PAIRS=${TMP_JSON}.pairs

log() { printf '%s\n' "$*"; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }
cleanup() { rm -f "$TMP_JSON" "$TMP_PAIRS" "${BIN}.$$"; }
trap cleanup EXIT INT TERM

find_config() {
  for candidate in "$CF_ROUTE_CONFIG" /etc/config/cf-probe/config.conf "$HOME/.cf-probe/config.conf" /data/config.conf; do
    if [ -n "$candidate" ] && [ -r "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

config_value() {
  grep -E "^$2=" "$1" 2>/dev/null | tail -n 1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//'
}

map_code() {
  case $1 in
    ct_cn2*) echo CN2 ;;
    ct_ctgnet) echo CTGNET ;;
    ct_163) echo 163 ;;
    cu_9929*) echo 9929 ;;
    cu_cug) echo CUG ;;
    cu_4837) echo 4837 ;;
    cm_cmin2*) echo CMIN2 ;;
    cm_cmi) echo CMI ;;
    cm_cmnet) echo CMNET ;;
    *) return 1 ;;
  esac
}

ensure_binary() {
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) asset=amd64 ;;
    i386|i686) asset=386 ;;
    aarch64|arm64) asset=arm64 ;;
    armv7l|armv8l|armv8) asset=arm ;;
    *) die "unsupported architecture: $arch" ;;
  esac

  if [ "$CF_ROUTE_REFRESH" != "1" ] && [ -x "$BIN" ]; then
    return 0
  fi

  log "downloading backtrace binary..."
  tmp_bin="${BIN}.$$"
  curl -fsSL --retry 2 -o "$tmp_bin" \
    "https://github.com/oneclickvirt/backtrace/releases/latest/download/backtrace-linux-${asset}" \
    || die "failed to download backtrace binary"
  chmod 0755 "$tmp_bin"
  mv "$tmp_bin" "$BIN" || die "failed to install $BIN"
}

run_report() {
  cfg=$(find_config) || die "cf-probe config not found (set CF_ROUTE_CONFIG)"
  SERVER_ID=$(config_value "$cfg" SERVER_ID)
  SECRET=$(config_value "$cfg" SECRET)
  WORKER_URL=$(config_value "$cfg" WORKER_URL)

  [ -n "$SERVER_ID" ] || die "SERVER_ID missing in $cfg (auto-discovery installs cannot report routes)"
  [ -n "$SECRET" ] || die "SECRET missing in $cfg"
  [ -n "$WORKER_URL" ] || die "WORKER_URL missing in $cfg"

  api=${WORKER_URL%/}
  case "$api" in
    */update) api=${api%/update} ;;
  esac
  api="${api}${API_PATH}"

  ensure_binary

  log "probing return routes (this can take 1-3 minutes)..."
  if command -v timeout >/dev/null 2>&1; then
    timeout 300 "$BIN" -route-json -route-attempts 2 -timeout 120s >"$TMP_JSON" 2>/dev/null
  else
    "$BIN" -route-json -route-attempts 2 -timeout 120s >"$TMP_JSON" 2>/dev/null
  fi
  [ -s "$TMP_JSON" ] || die "no report produced (traceroute failed or binary missing)"

  awk '
    /"carrier":/ { s=$0; sub(/.*"carrier":[[:space:]]*"/, "", s); sub(/".*/, "", s); c=s }
    /"code":/    { s=$0; sub(/.*"code":[[:space:]]*"/, "", s); sub(/".*/, "", s); code=s }
    /"rank":/ {
      if (c != "" && code != "") {
        s=$0; sub(/.*"rank":[[:space:]]*/, "", s); sub(/[^0-9].*/, "", s);
        print c, code, (s == "" ? 0 : s)
        c=""; code=""
      }
    }
  ' "$TMP_JSON" >"$TMP_PAIRS"

  ct=""; cu=""; cm=""
  ct_rank=-1; cu_rank=-1; cm_rank=-1

  while read -r carrier code rank; do
    [ -n "$carrier" ] || continue
    label=$(map_code "$code") || label=""
    [ -n "$label" ] || continue
    case "$carrier" in
      ct) if [ "$rank" -ge "$ct_rank" ]; then ct=$label; ct_rank=$rank; fi ;;
      cu) if [ "$rank" -ge "$cu_rank" ]; then cu=$label; cu_rank=$rank; fi ;;
      cm) if [ "$rank" -ge "$cm_rank" ]; then cm=$label; cm_rank=$rank; fi ;;
    esac
  done <"$TMP_PAIRS"

  body="{\"server_id\":\"$SERVER_ID\""
  [ -n "$ct" ] && body="$body,\"ct_in\":\"$ct\""
  [ -n "$cu" ] && body="$body,\"cu_in\":\"$cu\""
  [ -n "$cm" ] && body="$body,\"cm_in\":\"$cm\""
  body="$body}"

  if [ "$body" = "{\"server_id\":\"$SERVER_ID\"}" ]; then
    die "route detection returned no usable carrier result"
  fi

  log "telecom=$ct union=$cu mobile=$cm"
  response=$(curl -fsS -m 30 -X POST "$api" \
    -H 'Content-Type: application/json' \
    -H "X-API-Secret: $SECRET" \
    -d "$body" 2>&1) || die "upload failed: $response"
  log "uploaded: $response"
}

do_install() {
  self=$0
  case "$self" in
    /*) ;;
    *) self=$(cd "$(dirname "$self")" && pwd)/$(basename "$self") ;;
  esac

  if [ "$self" != "$CRON_TAG" ]; then
    cp "$self" "$CRON_TAG" || die "failed to copy to $CRON_TAG"
    chmod 0755 "$CRON_TAG"
  fi

  if command -v crontab >/dev/null 2>&1; then
    ( crontab -l 2>/dev/null | grep -vF "$CRON_TAG"; echo "23 */6 * * * $CRON_TAG >/dev/null 2>&1" ) \
      | crontab - || log "[WARN] failed to install cron entry"
    log "cron installed: every 6 hours at minute 23"
  else
    log "[WARN] crontab not found; add a systemd timer for $CRON_TAG"
  fi

  run_report
}

do_uninstall() {
  if command -v crontab >/dev/null 2>&1; then
    crontab -l 2>/dev/null | grep -vF "$CRON_TAG" | crontab - 2>/dev/null
  fi
  rm -f "$CRON_TAG"
  log "uninstalled"
}

case "${1:-run}" in
  run|'') run_report ;;
  install) do_install ;;
  uninstall) do_uninstall ;;
  *) die "unknown command: $1" ;;
esac
