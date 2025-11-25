#!/bin/bash

NAMESPACE="nettest"
GATEWAY_NS="omni-system"

echo "=== Applying All Gateway Configurations ==="
echo ""

echo "Step 1: Apply Gateway (if not already applied)..."
kubectl apply -f k8s/ILB-test/gateway.yaml
echo ""

echo "Step 2: Apply app2-service..."
kubectl apply -f k8s/app2-service.yaml
echo ""

echo "Step 3: Apply app2-deployment (with health probes)..."
kubectl apply -f k8s/app2-deployment.yaml
echo ""

echo "Step 4: Wait for app2 pods to be ready..."
kubectl wait --for=condition=ready pod -l app=app2 -n $NAMESPACE --timeout=120s || echo "Pods not ready yet"
echo ""

echo "Step 5: Verify service endpoints are populated..."
sleep 5
kubectl get endpoints app2-service -n $NAMESPACE
echo ""

echo "Step 6: Apply HTTPRoute..."
kubectl apply -f k8s/ILB-test/app2-route.yaml
echo ""

echo "Step 7: Wait for HTTPRoute to be accepted..."
sleep 5
kubectl get httproute app2-internal-route -n $NAMESPACE
echo ""

echo "Step 8: Check HTTPRoute status..."
kubectl describe httproute app2-internal-route -n $NAMESPACE | grep -A 15 "Status:"
echo ""

echo "Step 9: Verify Gateway status..."
kubectl get gateway omni-internal-http-gateway -n $GATEWAY_NS
echo ""

echo "Step 10: Apply app1-configmap..."
kubectl apply -f k8s/app1-configmap.yaml
echo ""

echo "Step 11: Restart app1 to pick up config..."
kubectl rollout restart deployment/app1 -n $NAMESPACE
echo ""

echo "=== Verification ==="
echo ""
echo "1. Check Gateway IP:"
kubectl get gateway omni-internal-http-gateway -n $GATEWAY_NS -o jsonpath='{.status.addresses[0].value}' && echo ""
echo ""

echo "2. Check app2-service endpoints:"
ENDPOINTS=$(kubectl get endpoints app2-service -n $NAMESPACE -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null)
if [ -z "$ENDPOINTS" ]; then
  echo "❌ No endpoints found - Gateway cannot route!"
else
  echo "✓ Endpoints: $ENDPOINTS"
fi
echo ""

echo "3. Check app2 pods:"
kubectl get pods -n $NAMESPACE -l app=app2
echo ""

echo "=== Done ==="
echo ""
echo "Monitor logs:"
echo "  kubectl logs -l app=app1 -n $NAMESPACE -f | grep REQUEST"
echo "  kubectl logs -l app=app2 -n $NAMESPACE -f | grep REQUEST"

