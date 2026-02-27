#!/usr/bin/env bash
# codex-review.sh — Run codex exec review against a base branch
# Usage: codex-review.sh [base-branch] [output-file] [focus] [timeout-seconds]

set -uo pipefail

BASE_BRANCH="${1:-staging}"
OUTPUT_FILE="${2:-/tmp/codex-review-findings.md}"
FOCUS="${3:-}"
TIMEOUT="${4:-300}"

# ── Preflight checks ────────────────────────────────────────────

if ! command -v codex &>/dev/null; then
  echo "ERROR: codex CLI not found." >&2
  echo "Install: npm install -g @openai/codex  (or see https://github.com/openai/codex)" >&2
  exit 1
fi

if ! git rev-parse --git-dir &>/dev/null; then
  echo "ERROR: not inside a git repository" >&2
  exit 1
fi

if ! git rev-parse --verify "$BASE_BRANCH" &>/dev/null 2>&1; then
  echo "ERROR: base branch '$BASE_BRANCH' not found." >&2
  echo "Try: git fetch origin $BASE_BRANCH:$BASE_BRANCH" >&2
  exit 1
fi

DIFF_STAT=$(git diff --stat "$BASE_BRANCH"...HEAD 2>/dev/null | tail -1)
if [ -z "$DIFF_STAT" ]; then
  echo "No changes detected vs '$BASE_BRANCH'. Nothing to review." >&2
  echo "LGTM — no diff to review." > "$OUTPUT_FILE"
  exit 0
fi

echo "Diff: $DIFF_STAT" >&2
echo "Running codex review against base: $BASE_BRANCH" >&2
[ -n "$FOCUS" ] && echo "Focus: $FOCUS" >&2

# ── Run review ──────────────────────────────────────────────────
# Focus prompt goes BEFORE flags per codex CLI convention

run_review() {
  if [ -n "$FOCUS" ]; then
    timeout "$TIMEOUT" codex exec review "$FOCUS" --base "$BASE_BRANCH"
  else
    timeout "$TIMEOUT" codex exec review --base "$BASE_BRANCH"
  fi
}

run_review > "$OUTPUT_FILE" 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
  echo "ERROR: codex timed out after ${TIMEOUT}s." >&2
  echo "Try a smaller diff, increase timeout (4th arg), or split your changes." >&2
  exit 1
elif [ $EXIT_CODE -ne 0 ]; then
  # Non-zero exit may still have partial/useful output — warn but continue
  echo "Warning: codex exited $EXIT_CODE — output may be partial" >&2
fi

if [ ! -s "$OUTPUT_FILE" ]; then
  echo "ERROR: codex produced no output" >&2
  exit 1
fi

echo "Review complete → $OUTPUT_FILE" >&2
cat "$OUTPUT_FILE"
