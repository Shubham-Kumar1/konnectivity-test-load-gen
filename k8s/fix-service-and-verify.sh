#!/bin/bash

NAMESPACE="nettest"

echo "=== Fixing Service and Verifying ==="
echo ""

echo "1. Applying updated service (regular ClusterIP instead of headless)..."
kubectl apply -f k8s/app2-service.yaml
echo ""

echo "2. Waiting a few seconds for service to update..."
sleep 5
echo ""

echo "3. Checking service endpoints..."
kubectl get endpoints app2-service -n $NAMESPACE
echo ""

echo "4. Checking pod status..."
kubectl get pods -n $NAMESPACE -l app=app2
echo ""

echo "5. Verifying endpoints have IPs..."
ENDPOINT_IPS=$(kubectl get endpoints app2-service -n $NAMESPACE -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null)
if [ -z "$ENDPOINT_IPS" ]; then
  echo "❌ Still no endpoints!"
  echo ""
  echo "Checking why pods aren't ready..."
  kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{range .items[*]}{.metadata.name}{": Ready="}{.status.containerStatuses[0].ready}{" Phase="}{.status.phase}{"\n"}{end}'
  echo ""
  echo "Check pod logs:"
  APP2_POD=$(kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ ! -z "$APP2_POD" ]; then
    echo "Pod: $APP2_POD"
    kubectl logs -n $NAMESPACE $APP2_POD --tail=20
  fi
else
  echo "✓ Endpoints found: $ENDPOINT_IPS"
  echo ""
  echo "6. Testing connection from app1..."
  APP1_POD=$(kubectl get pods -n $NAMESPACE -l app=app1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ ! -z "$APP1_POD" ]; then
    echo "Sending test request from app1 pod: $APP1_POD"
    kubectl exec -n $NAMESPACE $APP1_POD -- curl -s -o /dev/null -w "HTTP %{http_code}\n" --max-time 5 -H "Host: app2.omni-internal.com" http://app2.omni-internal.com:80/health || echo "Connection failed"
  fi
fi
echo ""

echo "=== Done ==="

