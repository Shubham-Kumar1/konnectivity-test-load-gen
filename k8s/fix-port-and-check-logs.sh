#!/bin/bash

NAMESPACE="nettest"

echo "=== Fixing Port and Checking Logs ==="
echo ""

echo "1. Updating ConfigMap to use port 80 (Gateway port)..."
kubectl patch configmap app1-config -n $NAMESPACE --type merge -p '{"data":{"TARGET_URL":"http://app2.omni-internal.com:80"}}'
echo "✓ ConfigMap updated"
echo ""

echo "2. Restarting app1 pods to pick up new configuration..."
kubectl rollout restart deployment/app1 -n $NAMESPACE
echo "Waiting for rollout..."
kubectl rollout status deployment/app1 -n $NAMESPACE --timeout=60s
echo ""

echo "3. Checking app2 logs (should see requests now)..."
echo "--- Recent app2 logs ---"
kubectl logs -n $NAMESPACE -l app=app2 --tail=20
echo ""

echo "4. Checking app2 log file..."
APP2_POD=$(kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$APP2_POD" ]; then
  echo "Checking log file in pod: $APP2_POD"
  kubectl exec -n $NAMESPACE $APP2_POD -- tail -20 /var/log/app2/app2.log 2>&1
else
  echo "No app2 pod found"
fi
echo ""

echo "5. Waiting 5 seconds for requests to come in..."
sleep 5
echo ""

echo "6. Checking app2 logs again for REQUEST entries..."
kubectl logs -n $NAMESPACE -l app=app2 --tail=30 | grep -i "REQUEST" || echo "No REQUEST logs found yet"
echo ""

echo "7. Verifying app1 is using correct URL..."
APP1_POD=$(kubectl get pods -n $NAMESPACE -l app=app1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$APP1_POD" ]; then
  echo "App1 pod environment:"
  kubectl exec -n $NAMESPACE $APP1_POD -- env | grep TARGET_URL
fi
echo ""

echo "=== Done ==="
echo "Monitor app2 logs with: kubectl logs -l app=app2 -f"

