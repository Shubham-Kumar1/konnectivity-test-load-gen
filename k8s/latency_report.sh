#!/usr/bin/env bash
set -euo pipefail

TMP_RAW="/tmp/latencies_raw.$$"
TMP_SORT="/tmp/latencies_sorted.$$"

# gather logs from all pods (current + previous containers) and extract latency (ms)
: > "$TMP_RAW"
for pod in $(kubectl get pods -l app=app1 -o name); do
  # remove "pod/" prefix if present in kubectl output (kubectl get -o name returns "pod/<name>")
  podname=${pod#pod/}
  # append logs (suppress errors if --previous not present)
  kubectl logs "$podname" --all-containers=true 2>/dev/null || true
  kubectl logs "$podname" --all-containers=true --previous 2>/dev/null || true
done \
| grep "Sent POST" \
| awk -F'[()]' '{
    # $2 contains like "2 ms"
    if ($2 ~ /[0-9]+[[:space:]]*ms/) {
      v = $2
      gsub(/[^0-9]/, "", v)
      if (v != "") print v
    }
  }' >> "$TMP_RAW"

# if no latencies found, exit cleanly
if [ ! -s "$TMP_RAW" ]; then
  echo "No latency lines found in available logs."
  rm -f "$TMP_RAW" "$TMP_SORT"
  exit 0
fi

# sort numeric
sort -n "$TMP_RAW" > "$TMP_SORT"

# basic stats
N=$(wc -l < "$TMP_SORT" | tr -d ' ')
SUM=$(awk '{s+=$1} END{print s+0}' "$TMP_SORT")
AVG=$(awk -v s="$SUM" -v n="$N" 'BEGIN{ if(n>0) printf("%.2f", s/n); else print "0.00"}')
MAX=$(tail -n1 "$TMP_SORT")
MIN=$(head -n1 "$TMP_SORT")

# percentiles (approx): p50, p95 (1-based index)
p50_idx=$(( (N + 1) / 2 ))
# approximate ceil for p95 index
p95_idx=$(( (N * 95 + 99) / 100 ))
[ $p50_idx -lt 1 ] && p50_idx=1
[ $p95_idx -lt 1 ] && p95_idx=1

P50=$(awk -v idx=$p50_idx 'NR==idx{print; exit}' "$TMP_SORT")
P95=$(awk -v idx=$p95_idx 'NR==idx{print; exit}' "$TMP_SORT")

# expanded bucket counts up to 10,000 ms
# buckets:
#  b_lt1        : <1 ms
#  b_1_4        : 1-4 ms
#  b_5_9        : 5-9 ms
#  b_10_49      : 10-49 ms
#  b_50_99      : 50-99 ms
#  b_100_499    : 100-499 ms
#  b_500_999    : 500-999 ms
#  b_1000_1999  : 1000-1999 ms (1-2s)
#  b_2000_4999  : 2000-4999 ms (2-5s)
#  b_5000_9999  : 5000-9999 ms (5-10s)
#  b_ge10000    : >=10000 ms (10s+)
read b_lt1 b_1_4 b_5_9 b_10_49 b_50_99 b_100_499 b_500_999 b_1000_1999 b_2000_4999 b_5000_9999 b_ge10000 <<'EOF'
0 0 0 0 0 0 0 0 0 0 0
EOF

while read -r ms; do
  if [ "$ms" -lt 1 ]; then
    b_lt1=$((b_lt1+1))
  elif [ "$ms" -lt 5 ]; then
    b_1_4=$((b_1_4+1))
  elif [ "$ms" -lt 10 ]; then
    b_5_9=$((b_5_9+1))
  elif [ "$ms" -lt 50 ]; then
    b_10_49=$((b_10_49+1))
  elif [ "$ms" -lt 100 ]; then
    b_50_99=$((b_50_99+1))
  elif [ "$ms" -lt 500 ]; then
    b_100_499=$((b_100_499+1))
  elif [ "$ms" -lt 1000 ]; then
    b_500_999=$((b_500_999+1))
  elif [ "$ms" -lt 2000 ]; then
    b_1000_1999=$((b_1000_1999+1))
  elif [ "$ms" -lt 5000 ]; then
    b_2000_4999=$((b_2000_4999+1))
  elif [ "$ms" -lt 10000 ]; then
    b_5000_9999=$((b_5000_9999+1))
  else
    b_ge10000=$((b_ge10000+1))
  fi
done < "$TMP_SORT"

# print report
cat <<REPORT
Latency distribution report (from all available kubectl logs for pods with label app=app1)
Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Log lines counted: $N

Buckets (ms):
  <1ms:         $b_lt1
  1–4ms:        $b_1_4
  5–9ms:        $b_5_9
  10–49ms:      $b_10_49
  50–99ms:      $b_50_99
  100–499ms:    $b_100_499
  500–999ms:    $b_500_999
  1000–1999ms:  $b_1000_1999
  2000–4999ms:  $b_2000_4999
  5000–9999ms:  $b_5000_9999
  >=10000ms:    $b_ge10000

Summary stats:
  min:   ${MIN} ms
  avg:   ${AVG} ms
  p50:   ${P50} ms
  p95:   ${P95} ms
  max:   ${MAX} ms

(If you want different bucket boundaries or CSV output, tell me which ranges you prefer.)
REPORT

# cleanup
rm -f "$TMP_RAW" "$TMP_SORT"

