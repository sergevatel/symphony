---
tracker:
  kind: linear
  api_key: $LINEAR_API_KEY
  project_slug: "omnideck-sdk-premium-accessible-card-framework-sep-18-a0caf567b0d6"
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
  interval_ms: 30000
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
    if [ -n "$(git status --porcelain --untracked-files=all | grep -Ev '^\?\? (\.symphony|Library|Library\.|Logs|Logs\.|Temp|Temp\.|UserSettings)(/|\.|$)' || true)" ]; then
      issue_id="$(basename "$PWD")"
      branch="$(git branch --show-current 2>/dev/null || true)"
      git add -u -- .
      git ls-files -o --exclude-standard \
        | grep -Ev '^(\.symphony|Library|Library\.|Logs|Logs\.|Temp|Temp\.|UserSettings)(/|\.|$)' \
        | tr '\n' '\0' \
        | xargs -0 git add -- 2>/dev/null || true
      if ! git diff --cached --quiet; then
        {
          printf '%s\n\n' "Land ${issue_id} Symphony workspace output"
          printf '%s\n\n' "This commit captures file changes produced by the Symphony issue agent so autonomous work is not stranded in an isolated workspace. The ticket branch remains separate from the OmniDeck baseline branch until integration review."
          printf "Constraint: Symphony workspaces are isolated from the baseline repo.\n"
          printf "Rejected: Leave workspace changes uncommitted | It hides progress from git and risks losing completed work.\n"
          printf "Confidence: medium\n"
          printf "Scope-risk: narrow\n"
          printf "Directive: Merge ticket branches through the landing/review path; do not treat Linear Done alone as baseline integration.\n"
          printf "Tested: Symphony after_run git status detection.\n"
          printf "Not-tested: Full Unity validation from hook context.\n"
        } > /tmp/symphony-commit-msg
        git commit -F /tmp/symphony-commit-msg
        if [ -n "$branch" ]; then
          git push -u origin "$branch" || true
        fi
      fi
    fi
agent:
  max_concurrent_agents: 3
  max_turns: 30
  max_retry_backoff_ms: 300000
  max_concurrent_agents_by_state:
    Todo: 3
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
  stall_timeout_ms: 120000
server:
  port: 4567
---

You are executing the OmniDeck SDK Unity Asset Store SDLC through Symphony.

Internal repo codename: Jumbo Playing Cards
Official commercial package name: OmniDeck SDK: Premium Accessible Card Framework

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
- Treat `docs/jumbo-card-ui-asset-package-prd.md` as the definitive SSOT product and SDLC contract when present.
- Use OmniDeck SDK naming for public/package-facing work. Treat "Jumbo Playing Cards" as an internal historical codename only.
- Do not introduce "Casino Royale" into production paths, namespaces, Unity metadata, screenshots, docs, or marketing copy.
- Implement the OmniDeck SDLC plan in the PRD: package foundation, tables, card backs, card fronts/decks, SDK runtime/tooling, A+ product leadership tooling, demos, docs, QA/compliance, and release evidence.
- Use local Unity `2022.3.62f2` for standard validation unless a Unity 6 editor is explicitly installed/available for compatibility validation.
- Do not open, close, or alter other Unity projects or Unity instances.
- Do not change UnityMCP transport setup. The SSOT is the existing HTTP hub at `http://127.0.0.1:8080/mcp` when Unity is intentionally used.
- Never promote or package anything from `Assets/JumboPlayingCardsPremium/Rejected`.
- Preserve production order unless Linear dependencies say otherwise: OmniDeck naming/package foundation first, tables second, card backs third, card fronts/decks fourth, SDK runtime/tooling fifth, A+ product leadership tooling sixth, then demos, docs, QA/compliance, and release evidence.
- Treat ODK-019 through ODK-024 as required A+ uplift lanes: OmniDeck Studio, Theme Composer, Accessibility Lab, Addressables/atlas/memory profiler, integration recipes, and visual quality promotion gate.
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
- Completion evidence is artifact-backed. The workpad must include at least one of:
  - A pushed ticket branch named `codex/jumbo-${issue_identifier}` with the commit hash.
  - A baseline commit hash already present in `codex/jumbo-sdlc-baseline-20260621`.
  - An explicit no-op/verification-only closeout explaining why no file artifact was required.
- Do not move an issue to `Done` when the only evidence is a Linear checklist or prose summary.
- If file changes exist but the ticket branch was not pushed, keep the issue in `In Review` and record the missing branch push as the blocker.

Move the issue to `In Review` when blocked by:

- Missing source files or auth.
- Missing pushed branch or missing baseline integration evidence.
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
