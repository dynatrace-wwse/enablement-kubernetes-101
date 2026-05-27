
<!-- The step below reads the environment variables and parses them to generate the API for the tenant,
 this way the dynakube is generated (default is the AppOnly one with Log ingest. Those are functions of the framework. -->

<!-- STEP_SETUP
commands:
  - dynatraceEvalReadSaveCredentials && generateDynakube
-->

# Section 2 — Deploy the DynaKube

The **DynaKube** is a Kubernetes Custom Resource that tells the Dynatrace Operator *how* to instrument your cluster — which tenant to connect to, which components to deploy, and how to configure them. Without a DynaKube, the operator is installed but idle.

## Step 1 — Open the Dynatrace UI

Normally you would navigate to:

**Infrastructure → Kubernetes → Connect cluster**

Click **Connect cluster** and follow the wizard. Dynatrace will generate two manifests:

1. A `Secret` containing your tenant URL, operator token, and ingest token
2. A `DynaKube` CR with the recommended configuration for your cluster

But since this is a managed environment, we have everything prepared for you. Just deploy the generated dynakube.yaml file in your cluster.

## Step 2 — Apply the generated manifests

Copy the `kubectl apply` command and run it in the Terminal:

```bash

kubectl apply -f /workspaces/enablement-kubernetes-101/.devcontainer/yaml/gen/dynakube.yaml 
```

!!! tip "Tenant credentials are pre-loaded"
    Your environment already has `DT_ENVIRONMENT`, `DT_OPERATOR_TOKEN`, and `DT_INGEST_TOKEN` set. The Dynatrace wizard will detect your tenant from these variables if you are signed in.

## Step 3 — Wait for OneAgent pods

After applying the DynaKube, the operator provisions a OneAgent DaemonSet. On a single-node cluster, one OneAgent pod will start.

```bash
kubectl get pods -n dynatrace --watch
```

Wait until all pods show `Running` before continuing.

## Validation — DynaKube object exists

<!-- LAB_QUESTION
type: shell-verification
question: "Verify the DynaKube custom resource was created"
buttonText: "Check DynaKube"
command: "kubectl get dynakube -n dynatrace --no-headers 2>/dev/null | grep -c ''"
expect:
  operator: gt
  value: 0
hint: "Apply the manifests from the Dynatrace UI wizard. The DynaKube CR must exist in the dynatrace namespace."
explanation: "DynaKube CR is present — the operator will now provision monitoring components."
-->

## Validation — ActiveGate pods are Running

TODO: Change this to verify the ActiveGate por is ready and running. It contains in the nage activegate and should be running.

<!-- LAB_QUESTION
type: shell-verification
question: "Verify the OneAgent DaemonSet pods are Running"
buttonText: "Check OneAgent Pods"
command: "kubectl get pods -n dynatrace --no-headers 2>/dev/null | grep -c Running"
expect:
  operator: gt
  value: 1
hint: "The OneAgent DaemonSet pod may take 1–2 minutes to start after the DynaKube is applied. Run `kubectl get pods -n dynatrace --watch` to monitor."
explanation: "OneAgent is running — your cluster nodes are now being instrumented."
-->


TODO: We tell the user that he can open the kubernetes cluster directly from heren, we can add a button to open in a new tab the kubernetes app, we need a way to make this dynamic like { app.kubernetes } that opens the ui/apps/dynatrace.kubernetes. 
