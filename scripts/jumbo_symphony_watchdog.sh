#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:/Users/sergevatel/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

SESSION="${SYMPHONY_JUMBO_TMUX_SESSION:-symphony-jumbo}"
URL="${1:-${SYMPHONY_JUMBO_STATE_URL:-http://127.0.0.1:4567/api/v1/state}}"
LOG="${SYMPHONY_JUMBO_HEARTBEAT_LOG:-/tmp/symphony-jumbo-heartbeat.jsonl}"
TMP_BODY="$(mktemp)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

tmux_status="missing"
if tmux has-session -t "${SESSION}" 2>/dev/null; then
  tmux_status="running"
fi

http_code="000"
if http_code="$(curl -fsS --max-time 10 -o "${TMP_BODY}" -w "%{http_code}" "${URL}" 2>/tmp/symphony-jumbo-watchdog.err)"; then
  body="$(tr '\n' ' ' < "${TMP_BODY}" | sed 's/"/\\"/g' | cut -c 1-1200)"
  printf '{"ts":"%s","session":"%s","tmux":"%s","state_url":"%s","http":%s,"status":"ok","body":"%s"}\n' \
    "${TS}" "${SESSION}" "${tmux_status}" "${URL}" "${http_code}" "${body}" >> "${LOG}"
else
  err="$(tr '\n' ' ' < /tmp/symphony-jumbo-watchdog.err | sed 's/"/\\"/g' | cut -c 1-600)"
  printf '{"ts":"%s","session":"%s","tmux":"%s","state_url":"%s","http":%s,"status":"failed","error":"%s"}\n' \
    "${TS}" "${SESSION}" "${tmux_status}" "${URL}" "${http_code}" "${err}" >> "${LOG}"
fi

rm -f "${TMP_BODY}"
tail -n 1 "${LOG}"
