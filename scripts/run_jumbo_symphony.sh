#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:/Users/sergevatel/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

SESSION="${SYMPHONY_JUMBO_TMUX_SESSION:-symphony-jumbo}"
SYMPHONY_ROOT="/Users/sergevatel/Claude-Projects/symphony"
ELIXIR_ROOT="${SYMPHONY_ROOT}/elixir"
WORKFLOW="${ELIXIR_ROOT}/WORKFLOW.jumbo.md"
LOG_ROOT="${SYMPHONY_JUMBO_LOG_ROOT:-${SYMPHONY_ROOT}/log/jumbo}"
PORT="${SYMPHONY_JUMBO_PORT:-4567}"

if tmux has-session -t "${SESSION}" 2>/dev/null; then
  echo "Symphony tmux session already running: ${SESSION}"
  exit 0
fi

mkdir -p "${LOG_ROOT}"

cmd=$(cat <<EOF
cd "${ELIXIR_ROOT}" && \
doppler run --project xcite --config dev -- \
mise exec -- ./bin/symphony \
  --i-understand-that-this-will-be-running-without-the-usual-guardrails \
  --logs-root "${LOG_ROOT}" \
  --port "${PORT}" \
  "${WORKFLOW}"
EOF
)

tmux new-session -d -s "${SESSION}" "${cmd}"
echo "Started Symphony tmux session: ${SESSION}"
echo "Dashboard: http://127.0.0.1:${PORT}/"
