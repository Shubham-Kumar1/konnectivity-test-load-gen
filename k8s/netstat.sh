for pod in $(kubectl get pods -l app=app2 -o jsonpath='{.items[*].metadata.name}'); do
  echo "Pod: $pod"
  kubectl exec "$pod" -- sh -c "netstat -an | grep ESTABLISHED | wc -l"
done

