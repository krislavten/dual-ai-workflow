# Sparring

A Claude Code plugin that brings automatic peer review to AI coding — one AI writes, another AI challenges.

Like sparring partners in boxing — they push each other to get better, not to win.

[中文](README.md)

## Why

AI agents write code fast, but mistakes slip through — hallucinated APIs, missed edge cases, subtle regressions. Having a human review every AI-generated change doesn't scale.

**This plugin adds a second AI as an automatic reviewer.** Claude Code writes the proposal and code, and the reviewer can be Cursor Agent, Codex CLI, or Zhipu GLM with a strict, find-the-bug mindset — up to 5 rounds until both agree. You only step in for key decisions. Supports primary + fallback — the workflow auto-degrades to the fallback backend when the primary fails.

The result: more reliable AI output, less manual review, lower cognitive load.

## Install

```
/plugin marketplace add krislavten/dual-ai-workflow
/plugin install sparring@sparring
```

Restart your session (`/exit`, then reopen `claude`), then run `/sparring:setup` to install dependencies and configure the reviewer model.

Pick your reviewer — **Cursor Agent / Codex CLI / Zhipu GLM**. Supports [primary + fallback](#primary--fallback) so a flaky primary doesn't block the workflow.

## Commands

| Command | Description |
|---------|-------------|
| `/sparring:setup` | Install deps, select model, configure permissions |
| `/sparring:workflow <task>` | Normal mode — co-design with user, auto peer review |
| `/sparring:yolo <task>` | YOLO mode — fully automated, confirm commit only |
| `/sparring:issue <project-url> [number]` | Issue mode — task from GitHub Issue |

## How It Works

```
You describe the task
  ↓
Executor writes proposal
  ↓
Reviewer challenges proposal (up to 5 rounds)
  ↓
You approve
  ↓
Executor implements code
  ↓
Reviewer challenges code (up to 5 rounds)
  ↓
You approve and commit
```

**Cross-Review Principle**: Before giving you any conclusion, recommendation, or decision — the executor gets it reviewed by the other AI first. Not just proposals and code, but any significant technical advice.

- **Normal mode** — You discuss the approach first, then AI pair handles review automatically
- **YOLO mode** — AI handles everything end-to-end, you only confirm the final commit
- **Issue mode** — Task comes from a GitHub Issue, all discussion syncs back to Issue comments

## Issue-Driven Workflow

A separate feature for teams that track work via GitHub Issues and Project boards.

Provide a Project board URL when using Issue mode:
```
/sparring:issue https://github.com/orgs/your-org/projects/3 106
```

What it does:
- Claims the issue, moves it to "In progress" on the board
- All AI discussions sync to Issue comments with identity markers
- Creates a PR when done, moves the issue to "Reviewing"

No fixed project config needed — pass the board URL per session.

## Multi-Agent Parallel + Review (with ClawTeam)

Sparring handles review quality. [ClawTeam](https://github.com/HKUDS/ClawTeam) handles multi-agent parallel orchestration. Use them together — each agent works in parallel with automatic peer review.

```
ClawTeam splits 3 tasks in parallel
  ├── Claude #1: auth module  ← Sparring: Cursor reviews
  ├── Claude #2: database     ← Sparring: Cursor reviews
  └── Claude #3: frontend     ← Sparring: Cursor reviews
```

### Install ClawTeam

```bash
pipx install clawteam
```

### Usage

```bash
# 1. Create team
clawteam team spawn-team my-project -d "Refactor user system" -n leader

# 2. Spawn workers, each with Sparring review
clawteam spawn tmux claude --team my-project --agent-name auth \
  --task "Implement auth module. Run workflow review-code my-project when done for Cursor review"

clawteam spawn tmux claude --team my-project --agent-name db \
  --task "Implement database layer. Run workflow review-code my-project when done for Cursor review"

# 3. Watch all agents work simultaneously
clawteam board attach my-project
```

## Reviewer Backend Configuration

Three backends supported, freely combinable as primary + fallback:

| Backend | Description | Notes |
|---------|-------------|-------|
| `cursor` | Cursor Agent (default) | Uses local Cursor account |
| `codex` | Codex CLI | Uses local OpenAI account |
| `glm` | Zhipu GLM API | Pay-as-you-go, ideal as fallback |

### Configuration

Precedence (low → high): **built-in defaults → global config → project config → env vars**.

```bash
# Generate global config (chmod 600, stores API key)
workflow config init

# Generate project config (team-shared backend choice; api_key stays global)
workflow config init project

# View merged effective config (keys masked)
workflow config show

# Get a single value
workflow config get review.backend
workflow config get glm.api_key   # returns masked
```

**Global config** `~/.config/sparring/config.json` (chmod 600, contains api_key, do not commit):

```json
{
  "review": {
    "backend": "cursor",
    "fallback": "glm",
    "timeout": 60,
    "retries": 1
  },
  "glm": {
    "api_key": "<id.secret>",
    "model": "glm-5.1"
  }
}
```

**Project config** `.sparring/config.json` (commit by default for team sharing; `.sparring/.gitignore` blocks secrets):

```json
{
  "review": {
    "backend": "cursor",
    "fallback": "glm"
  }
}
```

### Primary + Fallback

If the primary backend fails (timeout, network error, or any reviewer failure), the workflow falls back to the secondary.

The log makes degradation explicit:
```
⚠ Primary backend Cursor Agent failed, falling back to GLM...
```

**Three common setups**:

- **A) GLM only** — `review.backend = glm`, pay-as-you-go
- **B) Cursor primary + GLM fallback** — recommended, survives Cursor outages (`review.backend = cursor`, `review.fallback = glm`)
- **C) Codex primary + GLM fallback** — preserve Codex quota

### Environment variables (override any config.json field)

`SPARRING_*` is the preferred prefix; legacy `WORKFLOW_*` still works. Name mapping: `SPARRING_<UPPER_SNAKE>` → `key.path`.

```bash
# Common
export SPARRING_REVIEW_BACKEND=glm       # review.backend
export SPARRING_REVIEW_FALLBACK=cursor   # review.fallback
export SPARRING_GLM_API_KEY=<id.secret>  # glm.api_key
export SPARRING_REVIEW_TIMEOUT=120       # review.timeout
export SPARRING_REVIEW_RETRIES=2         # review.retries

# Legacy (still honored)
export WORKFLOW_REVIEW_BACKEND=glm
export WORKFLOW_REVIEW_BACKEND_FALLBACK=cursor
export WORKFLOW_GLM_API_KEY=<id.secret>
```

### Backend-specific parameters

| key | default | notes |
|---|---|---|
| `cursor.model` | from `agents/cursor.md` | override via `SPARRING_CURSOR_MODEL` |
| `codex.model` | from codex config | e.g. `gpt-5.4` |
| `codex.effort` | null | `none\|minimal\|low\|medium\|high\|xhigh` |
| `codex.home` | `/tmp/workflow-codex-home-<user>` | codex local state |
| `glm.api_key` | **required** | get one at <https://open.bigmodel.cn/usercenter/apikeys> |
| `glm.model` | `glm-5.1` | other Zhipu models |
| `glm.thinking` | `disabled` | `enabled` for better quality but slower |
| `glm.max_tokens` | `8192` | bump to `65536` when thinking is enabled |
| `glm.temperature` | `0.3` | review doesn't need high creativity |
| `glm.api_base` | official URL | swap for self-hosted gateway |

### Verify

```bash
workflow verify   # connectivity + model + masked key for primary/fallback
```

## Background Review Jobs (Optional)

For long-running reviews, run review jobs in the background:

```bash
workflow review-proposal-bg <task-id>
workflow review-code-bg <task-id>

workflow review-status [job-id|task-id]
workflow review-result <job-id>
workflow review-cancel <job-id>
```

## License

MIT
