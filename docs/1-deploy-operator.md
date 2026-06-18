
# Section 1 — Deploy the Dynatrace Operator

The **Dynatrace Operator** is a Kubernetes operator that manages the full lifecycle of Dynatrace monitoring components inside your cluster. It watches for `DynaKube` custom resources and automatically provisions the monitoring configuration that matches your desired mode.

## How it works

The [Dynatrace Operator](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/how-it-works/components/dynatrace-operator) is the central control plane for all Dynatrace monitoring inside Kubernetes. It follows the [operator pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/) — a custom controller that watches for [`DynaKube`](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/reference/dynakube-parameters) custom resources and reconciles the cluster state to match your desired monitoring configuration.

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

In [**Application-only monitoring**](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/deployment/application-observability) mode (used in this lab), the operator does **not** run a OneAgent DaemonSet on every node. Instead, it uses a [CSI driver](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/how-it-works/components/dynatrace-operator#csidriver) and a [mutating webhook](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/how-it-works/components/dynatrace-operator#webhook) to inject the Dynatrace agent library directly into application pod file systems at startup — no node-level privileges required.


### When you deploy the Dynatrace Operator

The following resources will be deployed by default in your cluster:

- **[Dynatrace Operator](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/how-it-works/components/dynatrace-operator)** — manages the automated rollout, configuration, and lifecycle of Dynatrace components in your Kubernetes environment.
- **[Dynatrace Webhook](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/how-it-works/components/dynatrace-operator#webhook)** — validates DynaKube definitions, converts definitions with older API versions, and injects configurations into Pods.
- **[Dynatrace CSI Driver](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/how-it-works/components/dynatrace-operator#csidriver)** — optional, deployed as a DaemonSet, provides writable volume storage for OneAgent binaries to minimize network and storage usage.


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

<!-- LAB_SOLUTION
reveal: |
  Run the three Helm commands above (create the `dynatrace` namespace, add the
  Dynatrace Helm repo, then `helm install dynatrace-operator`). The framework wraps
  all of this in a single helper, `dynatraceDeployOperator`, which the "Run solution"
  button executes for you and then confirms the operator pod is `Running`.
commands:
  - dynatraceDeployOperator
verify:
  - kubectl get pods -n dynatrace --no-headers 2>/dev/null | grep -q Running
-->
