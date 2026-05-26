
# Section 1 — Deploy the Dynatrace Operator

The **Dynatrace Operator** is a Kubernetes operator that manages the full lifecycle of Dynatrace monitoring components inside your cluster. It watches for `DynaKube` custom resources and automatically provisions OneAgent DaemonSets and ActiveGate deployments to match the desired monitoring configuration.

## How it works

```
kubectl apply DynaKube CR
       │
       ▼
Dynatrace Operator (watches CRDs)
       │
       ├─► OneAgent DaemonSet  → runs on every node, instruments processes (CloudNativeFullStack only)
       └─► ActiveGate          → routes data to your Dynatrace tenant
       └─► Webhooks            → Mutate pods before scheduling with init containers
       └─► CSI Driver          → manages loading of codemodules and images
```

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
hint: "Run the three Helm commands above in the Terminal tab. The `--atomic` flag will wait until the pod is ready."
explanation: "Operator manager pod is Running — ready to deploy the DynaKube."
-->

<!-- LAB_QUESTION
type: multiple-choice
question: "What does the Dynatrace Operator deploy by default with no Dynakube?"
options:
  - "A CSI Driver, the Dynatrace Operator and two Dynatrace Webhooks for resilience"
  - "A OneAgent DaemonSet so every node is automatically instrumented"
  - "A standalone Prometheus exporter that scrapes metrics"
  - "A second Kubernetes API server for high availability"
correct: 1
explanation: "The operator reconciles DynaKube CRs and rolls out a OneAgent DaemonSet — one agent pod per node — ensuring full cluster coverage without manual sidecar injection."
-->
