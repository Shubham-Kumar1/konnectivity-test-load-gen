for pod in $(kubectl get pods -l app=app1 -o jsonpath='{.items[*].metadata.name}'); do
  echo "Copying log from pod: $pod"
  kubectl cp "$pod:/var/log/app1/app1.log" "./$pod-app1.log"
done