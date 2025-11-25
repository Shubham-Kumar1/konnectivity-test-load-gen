#!/usr/bin/env bash

# Iterate through each pod with the app2 label
for p in $(kubectl get pods -l app=app2 -o jsonpath='{.items[*].metadata.name}'); do
  echo -e "\nEstablished connections for pod: $p"

  # Use kubectl exec to run netstat inside the pod and count established connections
  kubectl exec "$p" -- sh -c "
    netstat -an | grep ESTABLISHED | wc -l
  "
done

