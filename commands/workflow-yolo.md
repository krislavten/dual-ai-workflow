---
description: Fully automated dual AI workflow - AI handles everything, user only confirms final commit
argument-hint: <task-description> <claude|cursor>
---

# Dual AI Workflow - YOLO Mode

Fully automated execution. You handle everything, user only confirms final commit.

## Flow

```
User: /workflow-yolo <task> <executor>
  ↓
Executor: Draft proposal independently
  ↓
Executor ↔ Reviewer: Auto-iterate (no user)
  ↓
Executor: Implement code
  ↓
Executor ↔ Reviewer: Auto-iterate (no user)
  ↓
Executor: "Done! Commit? (yes/no)"
  ↓
User: yes → Commit!
```

## Instructions

### If YOU are the Executor

1. **Create task**: `workflow create "<name>" <executor>`

2. **Draft proposal independently**
   - Don't ask user for input
   - Use your best judgment
   - Write complete technical proposal
   - Save to `.workflow/plans/<task-id>/proposal.md`

3. **Auto-review loop**
   ```bash
   # Option A: Use CLI
   workflow review-proposal <task-id>

   # Option B: Call agent directly
   response=$(HTTP_PROXY= HTTPS_PROXY= agent --print --trust --model gpt-5.3-codex-xhigh "Review this proposal: ...")
   ```

4. **Implement code** — follow approved proposal, write tests

5. **Auto-code review loop**
   ```bash
   workflow review-code <task-id>
   ```

6. **Present final result** — summary, changes, review iterations, ask to commit

7. **If user approves**: Create commit

### If YOU are the Reviewer

- Wait to be called by executor via `agent --print`
- Review thoroughly
- Respond with `APPROVE` or `CONCERNS: <list>`
- Don't involve user

## When to Use YOLO

Good for: small well-defined tasks, bug fixes, routine refactoring, simple features.
Not good for: architectural changes, security-critical features, ambiguous requirements.

## Issue Sync

When a task has `issue_number` in `meta.json`, sync key steps to the Issue:

- **Cursor Agent reviews** are auto-synced by the `workflow` CLI with `🤖` marker
- **You (Claude/Executor)** must manually sync your actions:
  ```bash
  workflow issue-comment <number> "🧠 **[Claude Code — <Phase>]**

  <content>"
  ```
- Sync: proposal summary, implementation summary, final result
- **No `issue_number`?** Skip all sync, work purely locally.

## Notes

- **Speed**: Much faster than normal mode
- **Risk**: Higher - less human oversight
- **Audit**: Still full trail in `.workflow/plans/`
- **Rollback**: Easy with git if issues found later
