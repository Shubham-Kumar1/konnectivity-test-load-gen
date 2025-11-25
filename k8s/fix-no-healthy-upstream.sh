#!/bin/bash

NAMESPACE="nettest"

echo "=== Fixing 'no healthy upstream' Error ==="
echo ""

echo "1. Check app2 pods status:"
kubectl get pods -n $NAMESPACE -l app=app2 -o wide
echo ""

echo "2. Check if pods are Ready:"
kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\tReady: "}{.status.containerStatuses[0].ready}{"\tRestarts: "}{.status.containerStatuses[0].restartCount}{"\n"}{end}'
echo ""

echo "3. Check app2-service endpoints (CRITICAL):"
kubectl get endpoints app2-service -n $NAMESPACE -o yaml
echo ""

echo "4. Verify service selector matches pod labels:"
echo "Service selector:"
kubectl get svc app2-service -n $NAMESPACE -o jsonpath='{.spec.selector}' && echo ""
echo "Pod labels:"
kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.metadata.labels}{"\n"}{end}'
echo ""

echo "5. Check pod IPs vs endpoint IPs:"
echo "Pod IPs:"
kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.status.podIP}{" (Ready: "}{.status.containerStatuses[0].ready}{")\n"}{end}'
echo "Endpoint addresses:"
kubectl get endpoints app2-service -n $NAMESPACE -o jsonpath='{range .subsets[*]}{range .addresses[*]}{.ip}{" (Ready: "}{.conditions.ready}{")\n"}{end}{end}' 2>/dev/null || echo "No endpoints found"
echo ""

echo "6. Test pod health directly:"
APP2_POD=$(kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$APP2_POD" ]; then
  echo "Testing health endpoint on pod: $APP2_POD"
  kubectl exec -n $NAMESPACE $APP2_POD -- curl -s http://localhost:8080/health || echo "❌ Health check failed"
  echo ""
  echo "Testing /ping endpoint:"
  kubectl exec -n $NAMESPACE $APP2_POD -- curl -s http://localhost:8080/ping || echo "❌ Ping failed"
else
  echo "❌ No app2 pods found"
fi
echo ""

echo "7. Check pod logs for errors:"
if [ ! -z "$APP2_POD" ]; then
  kubectl logs -n $NAMESPACE $APP2_POD --tail=10
fi
echo ""

echo "8. Check HTTPRoute backend status:"
kubectl describe httproute app2-internal-route -n $NAMESPACE | grep -A 20 "Status:"
echo ""

echo "9. Check if pods have readiness probes:"
kubectl get deployment app2 -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' && echo "" || echo "No readiness probe configured"
echo ""

echo "=== Summary ==="
ENDPOINT_COUNT=$(kubectl get endpoints app2-service -n $NAMESPACE -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | wc -w)
READY_PODS=$(kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -c true)

echo "Ready pods: $READY_PODS"
echo "Endpoint IPs: $ENDPOINT_COUNT"

if [ "$ENDPOINT_COUNT" -eq 0 ]; then
  echo "❌ PROBLEM: No endpoints in service!"
  echo "   This means Gateway has no backend to route to"
  echo ""
  echo "   Possible causes:"
  echo "   - Pods are not Ready"
  echo "   - Service selector doesn't match pod labels"
  echo "   - Pods are in CrashLoopBackOff or Error state"
elif [ "$READY_PODS" -eq 0 ]; then
  echo "❌ PROBLEM: No pods are Ready!"
  echo "   Check pod status and logs"
else
  echo "✓ Pods and endpoints exist"
  echo "   If still getting 503, check Gateway health checks"
fi

