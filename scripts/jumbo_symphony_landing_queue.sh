#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:/Users/sergevatel/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

WORKSPACE_ROOT="${SYMPHONY_JUMBO_WORKSPACE_ROOT:-/Users/sergevatel/Claude-Projects/symphony-workspaces/jumbo-playing-cards}"
PROJECT_ID="${SYMPHONY_JUMBO_PROJECT_ID:-b13e71d7-0e61-41d0-ac24-739a741029d4}"
STATE_URL="${SYMPHONY_JUMBO_STATE_URL:-http://127.0.0.1:4567/api/v1/state}"
LOG="${SYMPHONY_JUMBO_LANDING_LOG:-/tmp/symphony-jumbo-landing-queue.jsonl}"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

emit() {
  printf '%s\n' "$1" >> "${LOG}"
  printf '%s\n' "$1"
}

if [ ! -d "${WORKSPACE_ROOT}" ]; then
  payload="$(printf '{"ts":"%s","status":"missing_workspace_root","workspace_root":%s}' "${TS}" "$(printf '%s' "${WORKSPACE_ROOT}" | json_escape)")"
  emit "${payload}"
  exit 0
fi

linear_states_json="{}"
active_issues=""
active_state_json="$(curl -fsS --max-time 10 "${STATE_URL}" 2>/dev/null || true)"
if [ -n "${active_state_json}" ]; then
  active_issues="$(printf '%s' "${active_state_json}" | jq -r '.running[]?.issue_identifier' 2>/dev/null || true)"
fi

if command -v doppler >/dev/null 2>&1; then
  linear_states_json="$(
    doppler run --project xcite --config dev -- python3 - "${PROJECT_ID}" <<'PY' 2>/dev/null || printf '{}'
import json
import os
import subprocess
import sys

project_id = sys.argv[1]
api_key = os.environ.get("LINEAR_API_KEY", "")
if not api_key:
    print("{}")
    raise SystemExit

payload = {
    "query": """
query ProjectIssues($id: String!) {
  project(id: $id) {
    issues(first: 250) {
      nodes { identifier state { name } title }
    }
  }
}
""",
    "variables": {"id": project_id},
}
proc = subprocess.run(
    [
        "curl",
        "-fsS",
        "-H",
        f"Authorization: {api_key}",
        "-H",
        "Content-Type: application/json",
        "https://api.linear.app/graphql",
        "--data-binary",
        "@-",
    ],
    input=json.dumps(payload),
    text=True,
    capture_output=True,
)
if proc.returncode != 0:
    print("{}")
    raise SystemExit
body = json.loads(proc.stdout)
nodes = body.get("data", {}).get("project", {}).get("issues", {}).get("nodes", [])
print(json.dumps({node["identifier"]: {"state": node["state"]["name"], "title": node["title"]} for node in nodes}))
PY
  )"
fi

summary_tmp="$(mktemp)"
trap 'rm -f "${summary_tmp}"' EXIT

for workspace in "${WORKSPACE_ROOT}"/CARD-*; do
  [ -d "${workspace}/.git" ] || continue
  issue="$(basename "${workspace}")"

  if printf '%s\n' "${active_issues}" | grep -qx "${issue}"; then
    continue
  fi

  dirty_count="$(git -C "${workspace}" status --porcelain --untracked-files=all \
    | { grep -Ev '^\?\? "?(\.symphony|Library|Library\.|Logs|Logs\.|Temp|Temp\.|UserSettings)(/|\.|$)' || true; } \
    | wc -l | tr -d ' ')"
  if [ "${dirty_count}" = "0" ]; then
    continue
  fi

  state="$(python3 - "${linear_states_json}" "${issue}" <<'PY'
import json
import sys
data = json.loads(sys.argv[1] or "{}")
issue = sys.argv[2]
print(data.get(issue, {}).get("state", "Unknown"))
PY
)"

  branch="$(git -C "${workspace}" branch --show-current 2>/dev/null || true)"
  head="$(git -C "${workspace}" rev-parse --short HEAD 2>/dev/null || true)"
  printf '%s|%s|%s|%s|%s\n' "${issue}" "${state}" "${dirty_count}" "${branch}" "${head}" >> "${summary_tmp}"

  if [ "${SYMPHONY_JUMBO_AUTOCOMMIT_WORKSPACES:-1}" != "1" ]; then
    continue
  fi

  git -C "${workspace}" add -u -- .
  git -C "${workspace}" ls-files -o --exclude-standard \
    | grep -Ev '^"?(\.symphony|Library|Library\.|Logs|Logs\.|Temp|Temp\.|UserSettings)(/|\.|$)' \
    | tr '\n' '\0' \
    | xargs -0 git -C "${workspace}" add -- 2>/dev/null || true
  if git -C "${workspace}" diff --cached --quiet; then
    continue
  fi

  git -C "${workspace}" commit -m "Land ${issue} Symphony workspace output" -m "This commits file changes produced inside the Symphony issue workspace so the work is not stranded outside git history. The branch remains isolated for review or later integration into the OmniDeck baseline branch.

Constraint: Symphony workspaces are isolated and the prior hook only wrote local run stamps.
Rejected: Mark Linear Done without a branch artifact | That makes the main repo appear idle and risks losing work.
Confidence: medium
Scope-risk: narrow
Directive: Review and merge this ticket branch before treating the baseline branch as updated.
Tested: git status/diff inspection before commit
Not-tested: Full Unity validation from landing queue script."

  if [ -n "${branch}" ]; then
    git -C "${workspace}" push -u origin "${branch}" || true
  fi
done

if [ ! -s "${summary_tmp}" ]; then
  emit "$(printf '{"ts":"%s","status":"no_dirty_workspaces","workspace_root":%s}' "${TS}" "$(printf '%s' "${WORKSPACE_ROOT}" | json_escape)")"
  exit 0
fi

python3 - "${summary_tmp}" "${TS}" "${WORKSPACE_ROOT}" <<'PY' | tee -a "${LOG}"
import json
import sys

summary_path, ts, workspace_root = sys.argv[1:4]
items = []
with open(summary_path, encoding="utf-8") as fh:
    for line in fh:
        issue, state, dirty, branch, head = line.rstrip("\n").split("|", 4)
        items.append({"issue": issue, "linear_state": state, "dirty_entries": int(dirty), "branch": branch, "head": head})
print(json.dumps({"ts": ts, "status": "dirty_workspaces_found", "workspace_root": workspace_root, "count": len(items), "items": items}, separators=(",", ":")))
PY
