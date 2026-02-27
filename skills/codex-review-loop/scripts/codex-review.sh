#!/usr/bin/env bash
# codex-review.sh — Run codex exec review against a base branch, output to file
# Usage: codex-review.sh [base-branch] [output-file] [focus]

set -euo pipefail

BASE_BRANCH="${1:-staging}"
OUTPUT_FILE="${2:-/tmp/codex-review-findings.md}"
FOCUS="${3:-}"

echo "Running codex review against base: $BASE_BRANCH" >&2
echo "Output file: $OUTPUT_FILE" >&2

if [ -n "$FOCUS" ]; then
  codex exec review \
    --base "$BASE_BRANCH" \
    "$FOCUS" \
    > "$OUTPUT_FILE"
else
  codex exec review \
    --base "$BASE_BRANCH" \
    > "$OUTPUT_FILE"
fi

echo "--- Review complete. Output written to: $OUTPUT_FILE ---" >&2
cat "$OUTPUT_FILE"
