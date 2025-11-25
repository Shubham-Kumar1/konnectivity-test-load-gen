#!/usr/bin/env bash

H=3600  # 1 hour in seconds
CURRENT_TIME=$(date +%s)

# Iterate through each pod with the app2 label
for p in $(kubectl get pods -l app=app2 -o jsonpath='{.items[*].metadata.name}'); do
  echo -e "\nLatency report for pod: $p"

  # Use kubectl exec to read from the log file inside the pod and generate latency report
  kubectl exec "$p" -- sh -c "
    cat /var/log/app2/app2.log | \
    while read line; do
      # Extract the timestamp from the log (assuming format [YYYY-MM-DDTHH:MM:SS.sssZ])
      log_time=\$(echo \$line | sed -n 's/.*\[\([^]]*\)\].*/\1/p')

      # Check if the timestamp is found and is valid
      if [ -z \"\$log_time\" ]; then
        continue
      fi

      # Convert log_time to Unix timestamp (MacOS version)
      log_timestamp=\$(date -j -f '%Y-%m-%dT%H:%M:%S' \"\$log_time\" +%s 2>/dev/null)

      # If the date conversion failed, skip this line
      if [ -z \"\$log_timestamp\" ]; then
        continue
      fi

      # Check if the log timestamp is within the last hour
      if [ \$((CURRENT_TIME - log_timestamp)) -le \$H ]; then
        echo \$line
      fi
    done
  " | grep -c "from app1"
done

