# Section 3 — Restart Application Services

The Dynatrace OneAgent injects itself into processes at startup time. Pods that were already running **before** the OneAgent DaemonSet was deployed will not be instrumented until they are restarted. This is a normal part of the OneAgent lifecycle.

## Why a restart is needed

When a pod starts, OneAgent's init container intercepts the process and injects the agent library. Pods that existed before OneAgent was deployed never went through this injection step, so restarting them triggers the injection.

## Step 1 — Restart all deployments in todoapp

```bash
kubectl rollout restart deployment -n todoapp
```

This triggers a rolling restart — new pods are started before old ones are terminated, so the application stays available throughout.

## Step 2 — Wait for the rollout to complete

```bash
kubectl rollout status deployment -n todoapp --timeout=120s
```

When the rollout finishes, the new pods will have been started with OneAgent already injected.

## Step 3 — Verify in Dynatrace

Open your Dynatrace tenant and navigate to **Services** or **Kubernetes** — within a few minutes you should see the `todoapp` service and its processes appearing automatically, with distributed traces flowing in.

## Validation

<!-- LAB_QUESTION
type: shell-verification
question: "Verify the todoapp pods are Running after the restart"
buttonText: "Check Application Pods"
command: "kubectl get pods -n todoapp --no-headers 2>/dev/null | grep -c Running"
expect:
  operator: gt
  value: 0
hint: "Run `kubectl rollout restart deployment -n todoapp` in the Terminal tab, then wait for the rollout to complete."
explanation: "Application pods are Running — OneAgent has been injected and instrumentation is active."
-->

## Verify logs in Dynatrace

Once OneAgent is injected and the services are running, Dynatrace will start collecting logs automatically. Trigger a log entry by creating a TODO item in the application, then verify it appears in Dynatrace.

```dql
dql: |
  fetch logs
  | filter k8s.namespace.name == "todoapp"
  | filter contains(content, "Adding a new todo: ")
  | limit 1
```

<!-- LAB_QUESTION
type: dql-verification
question: "Verify Dynatrace is collecting logs from the todoapp namespace"
buttonText: "Check DT Logs"
dql: |
  fetch logs
  | filter k8s.namespace.name == "todoapp"
  | filter contains(content, "Adding a new todo: ")
  | limit 1
expect:
  operator: not-empty
hint: "Open the TODO app, create a new item, then wait 1–2 minutes for logs to appear in Dynatrace."
explanation: "Dynatrace is collecting logs from todoapp — full observability is active."
-->

## Knowledge check

Answer the following questions to complete the training.

<!-- boundScenarioId: k8s-101-fundamentals -->

!!! success "Training complete!"
    Your cluster is now fully instrumented with Dynatrace. Head to **Services**, **Kubernetes**, and **Distributed Traces** in your tenant to explore the data being collected.
