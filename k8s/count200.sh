#!/usr/bin/env bash
set -euo pipefail

H=${1:-24h}   # optional arg: pass time window like "30m", "1h" or leave empty for default 24h

# Collect logs from all pods with label app=app1 (handles kubectl get -o name output "pod/<name>")
for p in $(kubectl get pods -l app=app1 -o name); do
  podname=${p#pod/}
  echo "=== Logs from $podname ==="
  # current logs (ignore failures for pods with no logs)
  kubectl logs "$podname" --since="$H" --all-containers=true 2>/dev/null || true
done \
| awk '
{
  # find pattern "-> 200" or "->   500" etc using three digit numeric class (no {3} used)
  if (match($0, /-> *[0-9][0-9][0-9]/)) {
    s = substr($0, RSTART, RLENGTH)    # e.g. "-> 200"
    gsub(/[^0-9]/, "", s)              # leave only digits -> "200"
    code = s
    counts[code]++
    total++
  }
}
END {
  if (total == 0) {
    print "No HTTP status codes found in the collected logs."
    exit
  }
  print ""
  print "===== HTTP Status Code Summary ====="
  for (c in counts) {
    printf "%s %d\n", c, counts[c]
  }
  print "------------------------------------"
  printf "TOTAL %d\n", total
  print ""
  print "Tip: to see the summary sorted by count, run: ./count_status_codes.sh | tail -n +5 | sort -k2 -nr"
}'

