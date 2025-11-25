#!/usr/bin/env bash

# Count established connections for each app2 pod
for pod in $(kubectl get pods -l app=app2 -o jsonpath='{.items[*].metadata.name}'); do
  echo -e "\nEstablished connections for pod: $pod"
  kubectl exec "$pod" -- sh -c "netstat -an | grep ESTABLISHED | wc -l"
done

