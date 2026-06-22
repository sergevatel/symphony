#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:/Users/sergevatel/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOME="${HOME:-/Users/sergevatel}"
export USER="${USER:-sergevatel}"

if [ -z "${DOPPLER_TOKEN:-}" ]; then
  DOPPLER_TOKEN="$(doppler configure get token --plain 2>/dev/null || true)"
  export DOPPLER_TOKEN
fi

STATE_URL="${SYMPHONY_JUMBO_STATE_URL:-http://127.0.0.1:4567/api/v1/state}"
REFRESH_URL="${SYMPHONY_JUMBO_REFRESH_URL:-http://127.0.0.1:4567/api/v1/refresh}"
PROJECT_SLUG="${SYMPHONY_JUMBO_PROJECT_SLUG:-omnideck-sdk-premium-accessible-card-framework-sep-18-a0caf567b0d6}"
LOG="${SYMPHONY_JUMBO_STARVATION_LOG:-/tmp/symphony-jumbo-starvation-recovery.jsonl}"
COOLDOWN_SECONDS="${SYMPHONY_JUMBO_STARVATION_COOLDOWN_SECONDS:-21600}"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

state_json="$(curl -fsS --max-time 15 "${STATE_URL}")"
running_count="$(printf '%s' "${state_json}" | jq -r '.counts.running // 0')"
retrying_count="$(printf '%s' "${state_json}" | jq -r '.counts.retrying // 0')"

if [ "${running_count}" != "0" ] || [ "${retrying_count}" != "0" ]; then
  printf '{"ts":"%s","status":"not_starved","running":%s,"retrying":%s}\n' \
    "${TS}" "${running_count}" "${retrying_count}" >> "${LOG}"
  tail -n 1 "${LOG}"
  exit 0
fi

doppler run --project xcite --config dev -- python3 - "${PROJECT_SLUG}" "${REFRESH_URL}" "${LOG}" "${TS}" "${COOLDOWN_SECONDS}" <<'PY'
from datetime import datetime, timezone
import json
import os
import re
import subprocess
import sys

project_slug, refresh_url, log_path, ts, cooldown_seconds_raw = sys.argv[1:6]
cooldown_seconds = int(cooldown_seconds_raw)
endpoint = "https://api.linear.app/graphql"
api_key = os.environ["LINEAR_API_KEY"]


def emit(payload):
    payload = {"ts": ts, **payload}
    with open(log_path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(payload, separators=(",", ":")) + "\n")
    print(json.dumps(payload, separators=(",", ":")))


def gql(query, variables):
    payload = json.dumps({"query": query, "variables": variables})
    proc = subprocess.run(
        [
            "curl",
            "-fsS",
            "-H",
            f"Authorization: {api_key}",
            "-H",
            "Content-Type: application/json",
            endpoint,
            "--data-binary",
            "@-",
        ],
        input=payload,
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"curl failed with {proc.returncode}")
    body = json.loads(proc.stdout)
    if body.get("errors"):
        raise RuntimeError(json.dumps(body["errors"]))
    return body


issues_query = """
query Issues($slug:String!) {
  issues(first: 250, filter: {project: {slugId: {eq: $slug}}}) {
    nodes {
      id
      identifier
      title
      priority
      state { id name type }
      labels { nodes { name } }
      relations(first: 20) {
        nodes { type relatedIssue { identifier state { name type } } }
      }
      inverseRelations(first: 20) {
        nodes { type issue { identifier state { name type } } }
      }
    }
  }
}
"""

data = gql(issues_query, {"slug": project_slug})["data"]["issues"]["nodes"]
issues = {issue["identifier"]: issue for issue in data}
terminal = {"Done", "Canceled", "Duplicate"}

todo_state_id = next(
    (issue["state"]["id"] for issue in data if issue["state"]["name"] == "Todo"),
    "44287fa4-4e65-45e4-9de1-4b75014c5791",
)

unfinished_tasks = [
    issue
    for issue in data
    if "[JPC-EPIC-" not in issue["title"] and issue["state"]["name"] not in terminal
]
if not unfinished_tasks:
    emit({"status": "complete_no_unfinished_tasks"})
    sys.exit(0)

blocked_by = {identifier: set() for identifier in issues}
for issue in data:
    ident = issue["identifier"]
    for relation in issue.get("relations", {}).get("nodes", []) or []:
        if relation.get("type") == "blocks":
            blocked_by.setdefault(relation["relatedIssue"]["identifier"], set()).add(ident)
    for relation in issue.get("inverseRelations", {}).get("nodes", []) or []:
        if relation.get("type") == "blocks":
            blocked_by.setdefault(ident, set()).add(relation["issue"]["identifier"])


def open_blockers(issue):
    return [
        blocker
        for blocker in sorted(blocked_by.get(issue["identifier"], set()))
        if issues[blocker]["state"]["name"] not in terminal
    ]


def issue_number(issue):
    match = re.search(r"\[(?:JPC|ODK|ODK-SDL)-(\d{3})\]", issue["title"])
    return int(match.group(1)) if match else 999


def release_owner_gate(issue):
    return "[JPC-032]" in issue["title"]


def ready(issue):
    labels = {label["name"] for label in issue["labels"]["nodes"]}
    return "symphony-ready" in labels


unblocked_todo = [
    issue
    for issue in unfinished_tasks
    if issue["state"]["name"] == "Todo" and ready(issue) and not open_blockers(issue)
]
if unblocked_todo:
    subprocess.run(["curl", "-fsS", "-X", "POST", "--max-time", "15", refresh_url], check=False)
    emit(
        {
            "status": "refresh_existing_unblocked_todo",
            "candidates": [issue["identifier"] for issue in unblocked_todo],
        }
    )
    sys.exit(0)

candidates = [
    issue
    for issue in unfinished_tasks
    if issue["state"]["name"] == "In Review"
    and ready(issue)
    and not open_blockers(issue)
    and not release_owner_gate(issue)
]

now = datetime.fromisoformat(ts.replace("Z", "+00:00"))
recent_promotions = {}
if os.path.exists(log_path):
    with open(log_path, "r", encoding="utf-8") as fh:
        for line in fh:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("status") != "promoted_review_to_todo" or not event.get("issue") or not event.get("ts"):
                continue
            try:
                promoted_at = datetime.fromisoformat(event["ts"].replace("Z", "+00:00"))
            except ValueError:
                continue
            recent_promotions[event["issue"]] = promoted_at


def promotion_age_seconds(issue):
    promoted_at = recent_promotions.get(issue["identifier"])
    if promoted_at is None:
        return None
    return (now - promoted_at).total_seconds()


eligible = [
    issue
    for issue in candidates
    if promotion_age_seconds(issue) is None or promotion_age_seconds(issue) >= cooldown_seconds
]

if eligible:
    candidates = eligible

candidates.sort(
    key=lambda issue: (
        issue.get("priority") or 99,
        promotion_age_seconds(issue) is not None,
        issue_number(issue),
        issue["identifier"],
    )
)

if not candidates:
    emit(
        {
            "status": "starved_no_promotable_review_issue",
            "unfinished": len(unfinished_tasks),
            "in_review": [
                issue["identifier"] for issue in unfinished_tasks if issue["state"]["name"] == "In Review"
            ],
            "cooldown_seconds": cooldown_seconds,
        }
    )
    sys.exit(0)

issue = candidates[0]
comment = f"""## Starvation Recovery

Triggered: `{ts}`

Symphony was idle with no running/retrying agents and the commercial package is not complete. This issue is `In Review`, `symphony-ready`, and has no open non-terminal blockers, so it is being re-promoted to `Todo` for another autonomous evidence/mining pass.

This does not approve marketplace submission, rights clearance, physical-device proof, or the final ship/no-ship decision. If the issue is truly blocked by a release-owner gate, the agent must return it to `In Review` with a concrete unblock brief.
"""

gql(
    """
mutation AddComment($issueId:String!, $body:String!) {
  commentCreate(input: {issueId: $issueId, body: $body}) { success }
}
""",
    {"issueId": issue["id"], "body": comment},
)
gql(
    """
mutation Promote($id:String!, $stateId:String!) {
  issueUpdate(id: $id, input: {stateId: $stateId}) {
    success
    issue { identifier state { name } }
  }
}
""",
    {"id": issue["id"], "stateId": todo_state_id},
)
subprocess.run(["curl", "-fsS", "-X", "POST", "--max-time", "15", refresh_url], check=False)

emit(
    {
        "status": "promoted_review_to_todo",
        "issue": issue["identifier"],
        "title": issue["title"],
        "priority": issue.get("priority"),
        "unfinished": len(unfinished_tasks),
    }
)
PY
