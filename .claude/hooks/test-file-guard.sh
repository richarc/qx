#!/usr/bin/env bash
# PreToolUse hook: blocks edits to existing test files without explicit human approval.
# Claude Code passes the hook payload as JSON on stdin; the target path is
# at .tool_input.file_path.

file_path=$(python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print((d.get('tool_input') or {}).get('file_path', '') or d.get('file_path', ''))
except Exception:
    print('')
")

# Only EXISTING files are guarded: writing a new test file is the first
# step of TDD and must stay possible.
if [[ -e "$file_path" ]] && { [[ "$file_path" == *"_test.exs" ]] || [[ "$file_path" == */test/* ]]; }; then
    echo "BLOCKED: Attempted to modify existing test file: $file_path" >&2
    echo "" >&2
    echo "Existing tests are never modified without explicit human approval (AGENTS.md," >&2
    echo "TDD Rules). Stop, explain what change you were trying to make and why, and wait" >&2
    echo "for the user to approve before proceeding." >&2
    exit 2
fi

exit 0
