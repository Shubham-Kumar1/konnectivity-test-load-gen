#!/usr/bin/env bash
set -euo pipefail

# Loop over all app2 log files in current directory
for file in app2-*.log; do
  echo "== Results for $file =="

  grep -Eo 'app1-[a-z0-9]([a-z0-9-]*)' "$file" \
  | sort \
  | uniq -c \
  | sort -nr \
  || echo " (no app1 pod requests found in $file)"

  echo
done

