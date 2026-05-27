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

## Validation — OneAgent injected

The check below verifies that the restarted pods have the `oneagent.dynatrace.com/injected: "true"` annotation set by the mutating webhook. This annotation is the definitive proof that the agent was successfully injected at pod startup.

<!-- LAB_QUESTION
type: shell-verification
question: "Verify OneAgent was injected into the todoapp pods"
buttonText: "Check Injection"
command: "kubectl get pods -n todoapp -o jsonpath='{.items[*].metadata.annotations.oneagent\\.dynatrace\\.com/injected}' 2>/dev/null | tr ' ' '\\n' | grep -c true"
expect:
  operator: gt
  value: 0
hint: "Run `kubectl rollout restart deployment -n todoapp` in the Terminal tab, then wait for the rollout to complete. The injection annotation is only set on pods started after the DynaKube was applied."
explanation: "OneAgent injected — the todoapp pods have the `oneagent.dynatrace.com/injected: true` annotation confirming agent injection at startup."
-->

## Verify logs in Dynatrace

Once OneAgent is injected and the services are running, Dynatrace will start collecting logs automatically. Trigger a log entry by opening the TODO app and creating a new item, then verify it appears in Dynatrace Notebooks.

Open DT Notebooks and run this DQL to explore your logs:

```
fetch logs
| filter k8s.namespace.name == "todoapp"
| filter contains(content, "Adding a new todo: ")
| filter timestamp > now() - 10m
| limit 5
```

!!! tip "Time filter"
    The query uses `filter timestamp > now() - 10m` to show only logs from the last 10 minutes. This ensures you see logs from **your** training session and not from previous runs.

<!-- LAB_QUESTION
type: dql-verification
question: "Verify Dynatrace is collecting logs from the todoapp namespace"
buttonText: "Check DT Logs"
dql: |
  fetch logs
  | filter k8s.namespace.name == "todoapp"
  | filter contains(content, "Adding a new todo: ")
  | filter timestamp > now() - 10m
  | limit 1
expect:
  operator: not-empty
hint: "Open the TODO app, create a new item, then wait 1–2 minutes for logs to appear in Dynatrace."
explanation: "Dynatrace is collecting logs from todoapp — full observability is active."
-->

## Explore your services in Dynatrace

Now that the application is instrumented, use the Dynatrace Services App to see the automatically discovered services, performance indicators, and distributed traces from the `todoapp` namespace.

[dt-app|dynatrace.services|Open Services App](placeholder)

## Knowledge check

Answer the following questions to complete the training.

<!-- boundScenarioId: k8s-101-fundamentals -->

!!! success "Training complete!"
    Your cluster is now fully instrumented with Dynatrace. Head to **Services**, **Kubernetes**, and **Distributed Traces** in your tenant to explore the data being collected.
