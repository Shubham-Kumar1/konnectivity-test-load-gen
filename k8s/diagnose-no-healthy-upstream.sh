#!/bin/bash

NAMESPACE="nettest"

echo "=== Diagnosing 'no healthy upstream' Error ==="
echo ""

echo "1. Check app2 pods status:"
kubectl get pods -n $NAMESPACE -l app=app2 -o wide
echo ""

echo "2. Check pod readiness:"
kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{range .items[*]}{.metadata.name}{"\tPhase: "}{.status.phase}{"\tReady: "}{.status.containerStatuses[0].ready}{"\tRestarts: "}{.status.containerStatuses[0].restartCount}{"\n"}{end}'
echo ""

echo "3. Check app2-service endpoints (CRITICAL):"
kubectl get endpoints app2-service -n $NAMESPACE -o yaml
echo ""

echo "4. Check if endpoints have IPs:"
ENDPOINT_IPS=$(kubectl get endpoints app2-service -n $NAMESPACE -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null)
if [ -z "$ENDPOINT_IPS" ]; then
  echo "❌ NO ENDPOINTS FOUND - This is the problem!"
else
  echo "✓ Endpoint IPs: $ENDPOINT_IPS"
fi
echo ""

echo "5. Check pod IPs:"
POD_IPS=$(kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.status.podIP}{"\n"}{end}')
echo "$POD_IPS"
echo ""

echo "6. Verify service selector matches pod labels:"
echo "Service selector:"
kubectl get svc app2-service -n $NAMESPACE -o jsonpath='{.spec.selector}' && echo ""
echo "Pod labels:"
kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.metadata.labels}{"\n"}{end}'
echo ""

echo "7. Test pod health endpoint directly:"
APP2_POD=$(kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$APP2_POD" ]; then
  echo "Testing /health on pod: $APP2_POD"
  kubectl exec -n $NAMESPACE $APP2_POD -- curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/health || echo "❌ Health check failed"
  echo ""
  echo "Testing /ping:"
  kubectl exec -n $NAMESPACE $APP2_POD -- curl -s http://localhost:8080/ping || echo "❌ Ping failed"
else
  echo "❌ No app2 pods found"
fi
echo ""

echo "8. Check readiness probe status:"
if [ ! -z "$APP2_POD" ]; then
  kubectl get pod $APP2_POD -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}' && echo " (ready)" || echo " (not ready)"
  echo "Readiness probe:"
  kubectl get pod $APP2_POD -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}' && echo ""
fi
echo ""

echo "9. Check pod events for errors:"
if [ ! -z "$APP2_POD" ]; then
  kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$APP2_POD --sort-by='.lastTimestamp' | tail -5
fi
echo ""

echo "10. Check HTTPRoute status:"
kubectl describe httproute app2-internal-route -n $NAMESPACE | grep -A 20 "Status:"
echo ""

echo "=== Summary ==="
ENDPOINT_COUNT=$(kubectl get endpoints app2-service -n $NAMESPACE -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | wc -w)
READY_PODS=$(kubectl get pods -n $NAMESPACE -l app=app2 -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -c true)

echo "Ready pods: $READY_PODS"
echo "Endpoint IPs: $ENDPOINT_COUNT"
echo ""

if [ "$ENDPOINT_COUNT" -eq 0 ]; then
  echo "❌ CRITICAL: Service has NO endpoints!"
  echo ""
  echo "Possible causes:"
  echo "  1. Pods are not Ready (readiness probe failing)"
  echo "  2. Service selector doesn't match pod labels"
  echo "  3. Pods are in CrashLoopBackOff or Error state"
  echo ""
  echo "Fix:"
  echo "  - Check pod status: kubectl get pods -n $NAMESPACE -l app=app2"
  echo "  - Check pod logs: kubectl logs -n $NAMESPACE -l app=app2"
  echo "  - Verify health endpoint works: kubectl exec -n $NAMESPACE <pod> -- curl http://localhost:8080/health"
elif [ "$READY_PODS" -eq 0 ]; then
  echo "❌ PROBLEM: Pods exist but none are Ready!"
  echo "  Check readiness probe and pod logs"
else
  echo "✓ Pods and endpoints exist"
  echo "  If still getting 503, Gateway health checks might be failing"
fi

