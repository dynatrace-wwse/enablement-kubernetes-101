
# Section 1 — Deploy the Dynatrace Operator

The **Dynatrace Operator** is a Kubernetes operator that manages the full lifecycle of Dynatrace monitoring components inside your cluster. It watches for `DynaKube` custom resources and automatically provisions the monitoring configuration that matches your desired mode.

## How it works

```
kubectl apply DynaKube CR
       │
       ▼
Dynatrace Operator (watches CRDs)
       │
       ├─► CSI Driver          → mounts code modules into application pods
       ├─► Mutating Webhook    → intercepts new pods and injects the agent
       └─► ActiveGate          → routes data to your Dynatrace tenant
```

In **AppOnly** mode (used in this lab), the operator does **not** run a OneAgent DaemonSet on every node. Instead, it uses a CSI driver and a mutating webhook to inject the Dynatrace agent library directly into application pod file systems at startup — no node-level privileges required.

## Step 1 — Create the dynatrace namespace

```bash
kubectl create namespace dynatrace
```

## Step 2 — Add the Dynatrace Helm repository

```bash
helm repo add dynatrace \
  https://raw.githubusercontent.com/Dynatrace/dynatrace-operator/main/config/helm/repos/stable
helm repo update
```

## Step 3 — Install the operator

```bash
helm install dynatrace-operator dynatrace/dynatrace-operator \
  -n dynatrace
```

!!! note "Verify the install"
    After the command returns, run `kubectl get pods -n dynatrace` to see the operator manager pod in `Running` state.

## Validation

The check below runs `kubectl get pods -n dynatrace` and counts pods in `Running` state. The operator manager pod must be running before you can continue.

<!-- LAB_QUESTION
type: shell-verification
question: "Verify the Dynatrace Operator is running in the dynatrace namespace"
buttonText: "Check Operator"
command: "kubectl get pods -n dynatrace --no-headers 2>/dev/null | grep -c Running"
expect:
  operator: gt
  value: 0
hint: "Run the three Helm commands above in the Terminal tab. Wait a few seconds for the operator pod to reach Running state."
explanation: "Operator manager pod is Running — ready to deploy the DynaKube."
-->

<!-- LAB_QUESTION
type: multiple-choice
question: "With AppOnly mode, the Dynatrace Operator does NOT run a OneAgent DaemonSet on every node. What does it use instead to instrument your application pods?"
options:
  - "A CSI driver that mounts code modules into each pod, combined with a mutating webhook that injects the agent at startup"
  - "A OneAgent DaemonSet that runs on every node and instruments all processes"
  - "Manual sidecar injection — the developer must add an init container to every pod YAML"
  - "A Prometheus exporter sidecar that is automatically added to every pod"
correct: 0
explanation: "AppOnly uses a CSI driver (for code module delivery) and a mutating webhook (for automatic injection at pod creation). No kernel-level DaemonSet is needed, making it suitable for restricted environments."
-->
