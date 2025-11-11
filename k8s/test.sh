H=1h
for p in $(kubectl get pods -l app=app2 -o jsonpath='{.items[*].metadata.name}'); do
  echo -n "$p "
  kubectl logs "$p" --since=$H | grep -c "from app1"
done

