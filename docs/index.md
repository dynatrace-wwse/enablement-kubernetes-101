# Kubernetes 101 — Dynatrace Observability

In this hands-on training you will instrument a live Kubernetes cluster with Dynatrace from scratch. The cluster and a demo application are already running in your environment. Your job is to deploy the Dynatrace Operator, configure observability via a DynaKube custom resource, and restart the application so Dynatrace can begin collecting metrics, traces, and logs automatically.

[hs-video](https://www.youtube.com/watch?v=X48VuDVv0do%7CKubernetes%20Tutorial%20for%20Beginners%7CNot%20familiar%20with%20Kubernetes%20yet%3F%20This%20comprehensive%20intro%20by%20TechWorld%20with%20Nana%20covers%20pods%2C%20services%2C%20deployments%2C%20and%20everything%20you%20will%20see%20in%20this%20lab.%20Will%20be%20replaced%20with%20a%20personalised%20welcome%20video.)

## What you will do

| Step | Action | Validates |
|------|--------|-----------|
| Prerequisites | Verify the cluster and demo app are ready | `kubectl get nodes`, `kubectl get pods` |
| 1 | Deploy the **Dynatrace Operator** via Helm | Operator pod is `Running` in `dynatrace` namespace |
| 2 | Deploy the **DynaKube** custom resource from the Dynatrace UI | DynaKube object exists; ActiveGate pod is `Running` |
| 3 | **Restart** the application services to pick up instrumentation | Application pods come back `Running` with the agent injected |

Each step has an automated shell check built into the documentation — you must pass the check before you can continue.

## Environment overview

Your training environment includes:

- A **k3d** single-node Kubernetes cluster
- A **TODO application** deployed in the `todoapp` namespace
- Your Dynatrace tenant credentials pre-loaded as environment variables (`DT_ENVIRONMENT`, `DT_OPERATOR_TOKEN`, `DT_INGEST_TOKEN`)

Open the **Terminal** tab above at any time to run kubectl commands directly against your cluster.

!!! tip "Before you start"
    Click **Start Environment** in the status bar above to provision your live environment. The shell check buttons on each step will not be active until the environment is ready.
