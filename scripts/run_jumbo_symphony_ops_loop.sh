#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:/Users/sergevatel/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

SESSION="${SYMPHONY_JUMBO_OPS_TMUX_SESSION:-symphony-jumbo-ops}"
SYMPHONY_ROOT="/Users/sergevatel/Claude-Projects/symphony"
GAME_ROOT="/Users/sergevatel/Documents/Jumbo Playing Cards"
LOG_ROOT="${SYMPHONY_JUMBO_OPS_LOG_ROOT:-${SYMPHONY_ROOT}/log/jumbo}"
INTERVAL_SECONDS="${SYMPHONY_JUMBO_OPS_INTERVAL_SECONDS:-300}"

if tmux has-session -t "${SESSION}" 2>/dev/null; then
  echo "Symphony Jumbo ops loop already running: ${SESSION}"
  exit 0
fi

mkdir -p "${LOG_ROOT}"

cmd=$(cat <<EOF
set -euo pipefail
export PATH="/usr/local/bin:/opt/homebrew/bin:/Users/sergevatel/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "${SYMPHONY_ROOT}"
while true; do
  ts=\$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "=== \${ts} jumbo ops loop ==="
  ./scripts/jumbo_symphony_watchdog.sh || true
  ./scripts/jumbo_symphony_landing_queue.sh || true
  ./scripts/jumbo_symphony_starvation_recovery.sh || true
  curl -sS http://127.0.0.1:4567/api/v1/state -o /tmp/symphony-state.json || true
  cd "${GAME_ROOT}" && doppler run --project xcite --config dev -- python3 tools/generate_omnideck_sdlc_dashboard.py --symphony-state /tmp/symphony-state.json --output-dir "${LOG_ROOT}/omnideck-sdlc-dashboard" || true
  cd "${SYMPHONY_ROOT}"
  sleep "${INTERVAL_SECONDS}"
done
EOF
)

tmux new-session -d -s "${SESSION}" "${cmd}" \; pipe-pane -o "cat >> '${LOG_ROOT}/ops-loop.log'"
echo "Started Symphony Jumbo ops loop: ${SESSION}"
echo "Log: ${LOG_ROOT}/ops-loop.log"
