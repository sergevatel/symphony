---
tracker:
  kind: linear
  api_key: $LINEAR_API_KEY
  project_slug: "jumbo-playing-cards-unity-asset-store-july-1-a0caf567b0d6"
  required_labels:
    - symphony-ready
  active_states:
    - Todo
    - In Progress
  terminal_states:
    - Done
    - Canceled
    - Duplicate
polling:
  interval_ms: 15000
workspace:
  root: /Users/sergevatel/Claude-Projects/symphony-workspaces/jumbo-playing-cards
hooks:
  timeout_ms: 600000
  after_create: |
    set -eu
    git clone --branch codex/jumbo-sdlc-baseline-20260621 git@github.com:sergevatel/jumbo-playing-cards.git .
    issue_branch="codex/jumbo-$(basename "$PWD")"
    git switch -c "$issue_branch"
  before_run: |
    set -eu
    test -d .git
    test -f ProjectSettings/ProjectVersion.txt
    grep -q 'm_EditorVersion: 2022.3.62f2' ProjectSettings/ProjectVersion.txt
    if [ -d Assets/JumboPlayingCardsPremium/Tables/Core10BrightnessPass ]; then
      echo "Rejected brightness pass is present in production table path" >&2
      exit 1
    fi
  after_run: |
    set -eu
    mkdir -p .symphony
    {
      printf 'timestamp=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf 'workspace=%s\n' "$PWD"
      printf 'branch=%s\n' "$(git branch --show-current 2>/dev/null || true)"
      printf 'head=%s\n' "$(git rev-parse --short HEAD 2>/dev/null || true)"
    } >> .symphony/run-stamps.log
agent:
  max_concurrent_agents: 3
  max_turns: 30
  max_retry_backoff_ms: 300000
  max_concurrent_agents_by_state:
    Todo: 2
    In Progress: 3
codex:
  command: codex --config shell_environment_policy.inherit=all --config 'model="gpt-5.4"' --config model_reasoning_effort=high app-server
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
    networkAccess: true
  turn_timeout_ms: 3600000
  read_timeout_ms: 5000
  stall_timeout_ms: 900000
server:
  port: 4567
---

You are executing the Jumbo Playing Cards Unity Asset Store SDLC through Symphony.

Linear issue: `{{ issue.identifier }}`

Title: {{ issue.title }}
State: {{ issue.state }}
Labels: {{ issue.labels }}
URL: {{ issue.url }}

Description:
{% if issue.description %}
{{ issue.description }}
{% else %}
No description provided.
{% endif %}

{% if attempt %}
Continuation context:

- This is retry attempt #{{ attempt }}.
- Resume from the current workspace and the existing `## Codex Workpad`.
- Do not restart completed investigation or validation unless current evidence is stale.
{% endif %}

## Operating Contract

- Work only inside this Symphony-created workspace.
- Treat `docs/jumbo-card-ui-asset-package-prd.md` as the product contract when present.
- Use local Unity `2022.3.62f2` for standard validation unless a Unity 6 editor is explicitly installed/available for compatibility validation.
- Do not open, close, or alter other Unity projects or Unity instances.
- Do not change UnityMCP transport setup. The SSOT is the existing HTTP hub at `http://127.0.0.1:8080/mcp` when Unity is intentionally used.
- Never promote or package anything from `Assets/JumboPlayingCardsPremium/Rejected`.
- Preserve production order: tables first, card backs second, card fronts/decks last.
- Treat premium AAA commercial quality as a release gate, not a marketing adjective.
- Support Unity versions from 2022 onward, including Unity 6. Use Unity 2022.3.62f2 as the minimum local validation floor, and record Unity 6 validation as a release gate when the issue touches compatibility, demos, scripts, prefabs, or packaging.
- For visual assets, run an adversarial visual review before promoting anything.
- For Unity work, prefer batchmode/import validation against this project only.
- Keep marketplace submission and final ship/no-ship approval as release-owner gates.

## Required Workpad

Use one persistent Linear comment named exactly:

`## Codex Workpad`

Before making edits:

1. Find or create the workpad comment.
2. Add an environment stamp: `<host>:<abs-workdir>@<short-sha>`.
3. Record the issue goal, acceptance criteria, validation plan, and current checklist.
4. Record the current branch, `git status --short`, and relevant repo facts.

During work:

- Update the same workpad after every meaningful milestone.
- Keep checklist items accurate.
- Add blockers immediately when discovered.
- Do not create extra completion-summary comments.

## Completion Rules

Move the issue to `Done` only when all are true:

- Acceptance criteria are met.
- Required tests or validation commands ran and passed.
- Relevant file paths and proof artifacts are recorded in the workpad.
- Visual or Unity changes have fresh evidence.
- Rejected assets remain excluded from production paths.

Move the issue to `In Review` when blocked by:

- Missing source files or auth.
- Required human rights/source-chain approval.
- Required physical-device proof.
- Irreversible release or marketplace submission decision.

The blocker note must say exactly what is missing, why it blocks the issue, and what action unblocks it.

## Baseline Validation Commands

Use the most relevant subset for the issue:

```bash
python3 -m unittest tests.test_table_brightness_pass tests.test_premium_table_variants_materialization tests.test_core_six_card_backs_materialization tests.test_gilded_celestial_deck_materialization
python3 - <<'PY'
from pathlib import Path
print('core10_tables=', len(list(Path('Assets/JumboPlayingCardsPremium/Tables/Core10/Textures/Tables').glob('*.png'))))
print('core_six_pngs=', len(list(Path('Assets/JumboPlayingCardsPremium/CardBacks/CoreSix').rglob('*.png'))))
print('production_brightness_path_exists=', Path('Assets/JumboPlayingCardsPremium/Tables/Core10BrightnessPass').exists())
print(Path('ProjectSettings/ProjectVersion.txt').read_text().splitlines()[0])
PY
```
