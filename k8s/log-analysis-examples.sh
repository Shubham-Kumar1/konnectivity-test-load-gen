#!/bin/bash

# Log Analysis Examples for app1 and app2
# This script provides examples of how to analyze the structured logs

NAMESPACE="nettest"

echo "=== Log Analysis Examples ==="
echo ""

# Get pod names
APP1_PODS=$(kubectl get pods -n $NAMESPACE -l app=app1 -o jsonpath='{.items[*].metadata.name}')
APP2_PODS=$(kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{.items[*].metadata.name}')

echo "1. View recent requests from app1:"
echo "   kubectl logs -n $NAMESPACE <app1-pod> --tail=50 | grep REQUEST"
echo ""

echo "2. View recent requests received by app2:"
echo "   kubectl logs -n $NAMESPACE <app2-pod> --tail=50 | grep REQUEST"
echo ""

echo "3. Find requests by requestId (trace a request across services):"
echo "   kubectl logs -n $NAMESPACE -l app=app1 | grep 'requestId=abc12345'"
echo "   kubectl logs -n $NAMESPACE -l app=app2 | grep 'requestId=abc12345'"
echo ""

echo "4. Find requests from a specific source pod:"
echo "   kubectl logs -n $NAMESPACE -l app=app2 | grep 'sourcePod=app1-xxx'"
echo ""

echo "5. Find requests to a specific destination pod:"
echo "   kubectl logs -n $NAMESPACE -l app=app1 | grep 'targetPod=app2-xxx'"
echo ""

echo "6. Calculate average latency:"
echo "   kubectl logs -n $NAMESPACE -l app=app1 | grep REQUEST_SUCCESS | grep -oP 'latencyMs=\\K[0-9]+' | awk '{sum+=\$1; count++} END {print \"Average latency:\", sum/count, \"ms\"}'"
echo ""

echo "7. Find high latency requests (>500ms):"
echo "   kubectl logs -n $NAMESPACE -l app=app1 | grep REQUEST_SUCCESS | grep -E 'latencyMs=[5-9][0-9]{2,}|latencyMs=[0-9]{4,}'"
echo ""

echo "8. Count requests per source pod:"
echo "   kubectl logs -n $NAMESPACE -l app=app2 | grep REQUEST_RECEIVED | grep -oP 'sourcePod=\\K[^ ]+' | sort | uniq -c"
echo ""

echo "9. Count requests per destination pod:"
echo "   kubectl logs -n $NAMESPACE -l app=app1 | grep REQUEST_SUCCESS | grep -oP 'targetPod=\\K[^ ]+' | sort | uniq -c"
echo ""

echo "10. View error requests:"
echo "    kubectl logs -n $NAMESPACE -l app=app1 | grep REQUEST_ERROR"
echo "    kubectl logs -n $NAMESPACE -l app=app2 | grep REQUEST_ERROR"
echo ""

echo "11. View log files directly:"
echo "    kubectl exec -n $NAMESPACE <app1-pod> -- tail -f /var/log/app1/app1.log"
echo "    kubectl exec -n $NAMESPACE <app2-pod> -- tail -f /var/log/app2/app2.log"
echo ""

echo "12. Extract all request flows (source -> destination):"
echo "    kubectl logs -n $NAMESPACE -l app=app1 | grep REQUEST_SUCCESS | grep -oP 'sourcePod=\\K[^ ]+.*targetPod=\\K[^ ]+'"
echo ""

echo "=== Current Pods ==="
echo "App1 pods:"
for pod in $APP1_PODS; do
  echo "  - $pod"
done
echo ""
echo "App2 pods:"
for pod in $APP2_PODS; do
  echo "  - $pod"
done

