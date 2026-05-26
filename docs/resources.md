# Resources

## Dynatrace documentation

- [Dynatrace Operator for Kubernetes](https://www.dynatrace.com/support/help/setup-and-configuration/setup-on-k8s/installation/dynatrace-operator)
- [DynaKube custom resource reference](https://www.dynatrace.com/support/help/setup-and-configuration/setup-on-k8s/reference/dynakube)
- [Kubernetes monitoring overview](https://www.dynatrace.com/support/help/platform-modules/infrastructure-monitoring/container-platform-monitoring/kubernetes)
- [OneAgent injection for containers](https://www.dynatrace.com/support/help/shortlink/oneagent-kubernetes)

## Quick reference — kubectl commands

```bash
# Cluster and node status
kubectl get nodes
kubectl cluster-info

# Namespace management
kubectl create namespace dynatrace
kubectl get namespaces

# Pod monitoring
kubectl get pods -n dynatrace --watch
kubectl get pods -n todoapp
kubectl describe pod <pod-name> -n dynatrace

# DynaKube
kubectl get dynakube -n dynatrace
kubectl describe dynakube -n dynatrace

# Rolling restart
kubectl rollout restart deployment -n todoapp
kubectl rollout status deployment -n todoapp

# Logs
kubectl logs -n dynatrace -l app=dynatrace-operator
kubectl logs -n dynatrace -l app=oneagent
```

## Dynatrace Helm chart reference

```bash
# Add repo
helm repo add dynatrace \
  https://raw.githubusercontent.com/Dynatrace/dynatrace-operator/main/config/helm/repos/stable

# Check installed release
helm list -n dynatrace

# Uninstall
helm uninstall dynatrace-operator -n dynatrace
```
