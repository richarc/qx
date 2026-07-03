#!/usr/bin/env bash
# Audit gate scoped to shipped dependencies.
#
# `mix hex.audit` flags every package in mix.lock, including dev/test-only
# deps (e.g. bypass -> cowboy -> cowlib) that never reach the published
# qx_sim package. This wrapper fails only when a flagged package is in the
# prod dependency tree; advisories confined to non-shipped deps are printed
# as warnings and pass.
set -uo pipefail

audit_out=$(mix hex.audit 2>&1)
audit_status=$?
echo "$audit_out"

if [ "$audit_status" -eq 0 ]; then
  echo "audit: clean"
  exit 0
fi

# Flagged package names: advisory lines ("  cowlib 2.18.0 - EEF-...") and
# retired-table rows both start with the package name followed by a version.
flagged=$(echo "$audit_out" \
  | grep -oE '^ *[a-z][a-z0-9_]* +[0-9]+\.[0-9]+' \
  | awk '{print $1}' | sort -u)

if [ -z "$flagged" ]; then
  echo "audit: failed but no flagged packages parsed; failing closed"
  exit 1
fi

shipped=$(mix deps.tree --only prod --format plain \
  | sed -n 's/^[|` -]*-- \([a-z0-9_]*\) .*/\1/p' | sort -u)

overlap=$(comm -12 <(echo "$flagged") <(echo "$shipped"))

if [ -n "$overlap" ]; then
  echo "audit: advisories affect SHIPPED deps:"
  echo "$overlap"
  exit 1
fi

echo "audit: advisories are confined to non-shipped (dev/test-only) deps:"
echo "$flagged"
echo "audit: shipped dependency tree is clean"
exit 0
