#!/bin/bash

NAMESPACE="nettest"

echo "=== Applying Health Probes to app2 ==="
echo ""

echo "1. Applying updated deployment with health probes..."
kubectl apply -f k8s/app2-deployment.yaml
echo ""

echo "2. Waiting for rollout..."
kubectl rollout status deployment/app2 -n $NAMESPACE --timeout=120s
echo ""

echo "3. Checking pod status..."
kubectl get pods -n $NAMESPACE -l app=app2
echo ""

echo "4. Checking service endpoints..."
kubectl get endpoints app2-service -n $NAMESPACE
echo ""

echo "5. Verifying pod is ready..."
sleep 5
READY=$(kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
if [ "$READY" == "true" ]; then
  echo "✓ Pod is Ready"
else
  echo "⚠️  Pod is not Ready yet, waiting..."
  kubectl wait --for=condition=ready pod -l app=app2 -n $NAMESPACE --timeout=60s
fi
echo ""

echo "6. Testing health endpoint..."
APP2_POD=$(kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$APP2_POD" ]; then
  kubectl exec -n $NAMESPACE $APP2_POD -- curl -s http://localhost:8080/health | head -3
fi
echo ""

echo "7. Checking endpoints again..."
kubectl get endpoints app2-service -n $NAMESPACE -o yaml | grep -A 5 "addresses:"
echo ""

echo "=== Done ==="
echo "If endpoints are populated, Gateway should now route traffic successfully"

