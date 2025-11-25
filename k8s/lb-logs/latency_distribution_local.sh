#!/usr/bin/env bash
set -euo pipefail

# buckets (ms) - starting from 400ms as requested
buckets=(0 400 800 1200 1600 2000 5000 10000)

for file in app2-*.log; do
  echo "== Latency distribution for $file =="

  # Try extracting numbers after "Processing time" first (case-insensitive).
  # Pattern: look for "Processing time" then a number; tolerate spaces and "ms".
  grep -i "processing time" "$file" \
    | grep -Eo '[0-9]+[[:space:]]*ms' \
    | sed 's/[^0-9]//g' > /tmp/times.$$.txt || true

  # If nothing found, fallback to first "<number> ms" on each line in the whole file.
  if [ ! -s /tmp/times.$$.txt ]; then
    grep -Eo '[0-9]+[[:space:]]*ms' "$file" \
      | sed 's/[^0-9]//g' > /tmp/times.$$.txt || true
  fi

  if [ ! -s /tmp/times.$$.txt ]; then
    echo " (no processing times found in $file)"
    echo
    rm -f /tmp/times.$$.txt
    continue
  fi

  # sort numeric
  sort -n /tmp/times.$$.txt > /tmp/times_sorted.$$.txt

  N=$(wc -l < /tmp/times_sorted.$$.txt | tr -d ' ')
  min=$(head -n1 /tmp/times_sorted.$$.txt)
  max=$(tail -n1 /tmp/times_sorted.$$.txt)
  sum=$(awk '{s+=$1} END{print s+0}' /tmp/times_sorted.$$.txt)
  avg=$(awk -v s="$sum" -v n="$N" 'BEGIN{ if(n>0) printf("%.2f", s/n); else print "0.00"}')

  # percentiles (1-based index, simple nearest-rank)
  p50_idx=$(( (N + 1) / 2 ))
  p90_idx=$(( (N * 90 + 99) / 100 ))
  p95_idx=$(( (N * 95 + 99) / 100 ))
  [ $p50_idx -lt 1 ] && p50_idx=1
  [ $p90_idx -lt 1 ] && p90_idx=1
  [ $p95_idx -lt 1 ] && p95_idx=1

  p50=$(awk -v idx=$p50_idx 'NR==idx{print; exit}' /tmp/times_sorted.$$.txt)
  p90=$(awk -v idx=$p90_idx 'NR==idx{print; exit}' /tmp/times_sorted.$$.txt)
  p95=$(awk -v idx=$p95_idx 'NR==idx{print; exit}' /tmp/times_sorted.$$.txt)

  echo "Count: $N"
  echo "Min: ${min} ms   Avg: ${avg} ms   P50: ${p50} ms   P90: ${p90} ms   P95: ${p95} ms   Max: ${max} ms"
  echo

  # bucket distribution
  total=$N
  for ((i=0; i<${#buckets[@]}-1; i++)); do
    low=${buckets[i]}
    high=${buckets[i+1]}
    count=$(awk -v l="$low" -v h="$high" '$1 >= l && $1 < h' /tmp/times_sorted.$$.txt | wc -l | tr -d ' ')
    pct=$(awk -v c="$count" -v t="$total" 'BEGIN{ if(t>0) printf("%.1f", c*100/t); else print "0.0"}')
    printf "%6s - %-6sms : %6d (%5s%%)\n" "$low" "$high" "$count" "$pct"
  done

  # last bucket >= last boundary
  last=${buckets[-1]}
  count=$(awk -v l="$last" '$1 >= l' /tmp/times_sorted.$$.txt | wc -l | tr -d ' ')
  pct=$(awk -v c="$count" -v t="$total" 'BEGIN{ if(t>0) printf("%.1f", c*100/t); else print "0.0"}')
  printf ">=%-6sms     : %6d (%5s%%)\n" "$last" "$count" "$pct"

  echo
  rm -f /tmp/times.$$.txt /tmp/times_sorted.$$.txt
done

