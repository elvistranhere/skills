---
name: codex-review-loop
description: "Automated code review and fix loop using OpenAI Codex CLI as reviewer and Claude Code as fixer. Use when the user says 'codex review', 'review loop', 'auto review and fix', 'review my code', or wants to run iterative code review against a base branch until all issues are resolved. Calls codex exec review to review the diff, Claude Code fixes the findings, then re-reviews until clean or max rounds reached."
allowed-tools: Bash(codex *), Read, Edit, Grep, Glob
---

# Codex Review Loop

Iterative review-fix cycle: Codex reviews the diff, Claude Code fixes, repeat until LGTM.

## Prerequisites

- `codex` CLI installed and authenticated (`codex --version` to verify)
- Inside a git repo with changes on the current branch vs a base branch

## Parameters

| Param | Default | Description |
|-------|---------|-------------|
| `BASE_BRANCH` | `staging` | Branch to diff against |
| `MAX_ROUNDS` | `5` | Safety cap to prevent infinite loops |
| `FOCUS` | _(none)_ | Optional review focus, e.g. "security", "performance" |
| `TYPECHECK_CMD` | _(none)_ | Optional command to run after fixes, e.g. `npx tsc --noEmit` |

## Workflow

### Step 1: Run Codex Review

Run the codex review and save findings to a temp file:

```bash
# Without focus
codex exec review --base <BASE_BRANCH> > /tmp/codex-review-findings.md

# With focus prompt
codex exec review --base <BASE_BRANCH> "<FOCUS>" > /tmp/codex-review-findings.md
```

Then read `/tmp/codex-review-findings.md`.

### Step 2: Parse Findings

Determine outcome:

- **Clean**: Contains "LGTM" or "no issues" or zero actionable findings → go to Step 5
- **Has findings**: Extract each finding (file, line, severity, description) → go to Step 3

Track each finding by a signature: `file:line:first_20_chars_of_description`. Store signatures per round for repeat detection.

### Step 3: Fix Findings

For each finding:

1. Check if this finding's signature appeared in a previous round → **skip** (repeat)
2. Read the file at the specified location
3. Understand the issue in context
4. Apply the fix using Edit tool
5. Skip subjective style preferences (info severity) or false positives — note them

After fixing all actionable findings, go to **Step 4**.

### Step 4: Verify & Loop

If `TYPECHECK_CMD` is set, run it. If it fails, fix the type errors before proceeding.

Increment round counter. If `round >= MAX_ROUNDS`, go to Step 5. Otherwise go back to **Step 1**.

### Step 5: Report

```
## Codex Review Loop Complete

- Rounds: <N>
- Base branch: <BASE_BRANCH>
- Findings fixed: <count>
- Findings skipped: <count> (with reasons: repeat/style/false-positive)
- Status: LGTM / Stopped at max rounds
```

## Loop Safety

- **MAX_ROUNDS cap**: Never exceed configured max (default 5).
- **Repeat detection**: Track finding signatures across rounds. If a finding appeared in a previous round, skip it. If ALL findings in a round are repeats, stop the loop immediately.
- **Type check gate**: If typecheck fails after fixes, fix before re-reviewing. Do not re-review with broken types.
- **No commits**: Do not commit or push. Leave that to the user.

## Codex CLI Quick Reference

- Built-in review: `codex exec review --base <branch>` (stdout=findings, stderr=progress)
- Also supports: `codex exec review --uncommitted` and `codex exec review --commit <sha>`
- Custom focus: `codex exec review --base <branch> "Focus on security"`
- Shorthand: `codex review --base <branch>` (same as `codex exec review`)
- Must be inside a git repo
- Timeout: can take 1-5 min per review depending on diff size
