#!/usr/bin/env bash
# PreToolUse hook: blocks edits to existing test files without explicit human approval.
# Claude Code passes tool input as JSON on stdin.

file_path=$(python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('file_path', ''))
except Exception:
    print('')
")

if [[ "$file_path" == *"_test.exs"* ]] || [[ "$file_path" == */test/* ]]; then
    echo "BLOCKED: Attempted to modify existing test file: $file_path" >&2
    echo "" >&2
    echo "The /implement workflow requires that existing tests are never modified without" >&2
    echo "explicit human approval. Stop, explain what change you were trying to make and why," >&2
    echo "and wait for the user to approve before proceeding." >&2
    exit 2
fi

exit 0
