#!/usr/bin/env bash
set -euo pipefail

TMP_RAW="/tmp/latencies_raw.$$"
TMP_SORT="/tmp/latencies_sorted.$$"

# Loop through all the pods individually
for pod in $(kubectl get pods -l app=app1 -o jsonpath='{.items[*].metadata.name}'); do
  echo "Processing pod: $pod"
  
  # Create temp files for each pod
  TMP_RAW_POD="/tmp/latencies_raw_$pod.$$"
  TMP_SORT_POD="/tmp/latencies_sorted_$pod.$$"
  
  # Gather logs from each pod and extract latencies (ms)
  : > "$TMP_RAW_POD"
  kubectl exec "$pod" -- cat /var/log/app1/app1.log | \
    grep "Sent POST" \
    | awk -F'[()]' '{
        if ($2 ~ /[0-9]+[[:space:]]*ms/) {
          v = $2
          gsub(/[^0-9]/, "", v)
          if (v != "") print v
        }
      }' >> "$TMP_RAW_POD"
  
  # If no latencies found for this pod, skip and continue
  if [ ! -s "$TMP_RAW_POD" ]; then
    echo "No latency lines found for pod: $pod"
    rm -f "$TMP_RAW_POD" "$TMP_SORT_POD"
    continue
  fi

  # Sort latency values numerically for this pod
  sort -n "$TMP_RAW_POD" > "$TMP_SORT_POD"

  # Basic stats for this pod
  N=$(wc -l < "$TMP_SORT_POD" | tr -d ' ')
  SUM=$(awk '{s+=$1} END{print s+0}' "$TMP_SORT_POD")
  AVG=$(awk -v s="$SUM" -v n="$N" 'BEGIN{ if(n>0) printf("%.2f", s/n); else print "0.00"}')
  MAX=$(tail -n1 "$TMP_SORT_POD")
  MIN=$(head -n1 "$TMP_SORT_POD")

  # Percentiles (p50, p95)
  p50_idx=$(( (N + 1) / 2 ))
  p95_idx=$(( (N * 95 + 99) / 100 ))
  P50=$(awk -v idx=$p50_idx 'NR==idx{print; exit}' "$TMP_SORT_POD")
  P95=$(awk -v idx=$p95_idx 'NR==idx{print; exit}' "$TMP_SORT_POD")

  # Bucket distribution starting from 400ms
  b_400_499=0
  b_500_999=0
  b_1000_1999=0
  b_2000_4999=0
  b_5000_9999=0
  b_ge10000=0

  while read -r ms; do
    if [ "$ms" -ge 400 ] && [ "$ms" -lt 500 ]; then
      b_400_499=$((b_400_499+1))
    elif [ "$ms" -ge 500 ] && [ "$ms" -lt 1000 ]; then
      b_500_999=$((b_500_999+1))
    elif [ "$ms" -ge 1000 ] && [ "$ms" -lt 2000 ]; then
      b_1000_1999=$((b_1000_1999+1))
    elif [ "$ms" -ge 2000 ] && [ "$ms" -lt 5000 ]; then
      b_2000_4999=$((b_2000_4999+1))
    elif [ "$ms" -ge 5000 ] && [ "$ms" -lt 10000 ]; then
      b_5000_9999=$((b_5000_9999+1))
    else
      b_ge10000=$((b_ge10000+1))
    fi
  done < "$TMP_SORT_POD"

  # Print the latency report for this pod
  cat <<REPORT
Latency distribution report for pod: $pod:
Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Log lines counted: $N

Buckets (ms):
  400–499ms:    $b_400_499
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
REPORT

  # Cleanup temp files for this pod
  rm -f "$TMP_RAW_POD" "$TMP_SORT_POD"
done
