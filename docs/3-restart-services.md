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
command: "source .devcontainer/util/source_framework.sh >/dev/null 2>&1 && waitForOneAgentInjected"
expect:
  operator: exit-zero
hint: "Run `kubectl rollout restart deployment -n todoapp` in the Terminal tab. The check waits up to ~4 min for the `oneagent.dynatrace.com/injected: true` annotation on the restarted pods."
explanation: "OneAgent injected — the todoapp pods have the `oneagent.dynatrace.com/injected: true` annotation confirming agent injection at startup."
-->

<!-- LAB_SOLUTION
reveal: |
  Restart the application so its pods pass through the OneAgent mutating webhook
  and get instrumented:

  ```bash
  kubectl rollout restart deployment -n todoapp
  kubectl rollout status deployment -n todoapp --timeout=120s
  ```

  The "Run solution" button runs both commands and confirms the restarted pods carry
  the `oneagent.dynatrace.com/injected: "true"` annotation.
commands:
  - kubectl rollout restart deployment -n todoapp && kubectl rollout status deployment -n todoapp --timeout=120s
verify:
  - "source .devcontainer/util/source_framework.sh >/dev/null 2>&1 && waitForOneAgentInjected"
-->

## Verify logs reach Grail (end-to-end)

This is the real end-to-end signal: app → OneAgent → Dynatrace Grail. We generate a **uniquely-tagged** TODO via the app's HTTP API, then confirm *that specific* log line arrives in Grail — so no other todo activity (or a previous run) can give a false pass.

### Step 1 — Generate a uniquely-tagged log line

`generateTodoTraffic` waits for the app's HTTP endpoint to answer, then creates a TODO whose title carries the tag `K8S101LOGPROBE` plus a per-run nonce (the same CURL path the Live Debugger lab uses to add a task). The app logs the title, so the tag lands in the log content.

<!-- LAB_QUESTION
type: shell-verification
question: "Generate a uniquely-tagged TODO so we can verify its log reaches Grail"
buttonText: "Generate tagged log"
command: "source .devcontainer/util/source_framework.sh >/dev/null 2>&1 && generateTodoTraffic"
expect:
  operator: exit-zero
hint: "Needs OneAgent injected (previous step) and the todoapp reachable via the ingress. The check waits for the endpoint, then POSTs the tagged TODO."
explanation: "A uniquely-tagged TODO was created — its log line should reach Grail within ~2 minutes."
-->

### Step 2 — Confirm the tagged log arrived in Grail

This DQL matches **only** the tagged probe log from the last 15 minutes — generic `Adding a new todo` logs and older runs are filtered out. The check button retries while the log makes its way to Grail.

```dql
fetch logs
| filter k8s.namespace.name == "todoapp"
| filter contains(content, "K8S101LOGPROBE")
| filter timestamp > now() - 15m
| limit 5
```

<!-- LAB_QUESTION
type: dql-verification
question: "Verify the uniquely-tagged TODO log reached Dynatrace Grail"
buttonText: "Check tagged log in Grail"
dql: |
  fetch logs
  | filter k8s.namespace.name == "todoapp"
  | filter contains(content, "K8S101LOGPROBE")
  | filter timestamp > now() - 15m
  | limit 1
expect:
  operator: not-empty
hint: "Run the previous step first. Logs take ~1–2 minutes to reach Grail — the check retries, so give it a moment."
explanation: "The tagged log reached Grail — the full app → OneAgent → Grail pipeline is verified end-to-end."
-->

!!! tip "Why the tag"
    Matching `K8S101LOGPROBE` (a probe-only marker) instead of the generic `Adding a new todo` guarantees the log came from **this** verification step, and the `now() - 15m` window keeps a previous run from giving a false pass.

## Explore your services in Dynatrace

Now that the application is instrumented, use the Dynatrace Services App to see the automatically discovered services, performance indicators, and distributed traces from the `todoapp` namespace.

[dt-app|dynatrace.services|Open Services App](placeholder)

## Knowledge check

Answer the following questions to complete the training.

<!-- LAB_QUESTIONAIRE: k8s-101-fundamentals retake=false -->

!!! success "Training complete!"
    Your cluster is now fully instrumented with Dynatrace. Head to **Services**, **Kubernetes**, and **Distributed Traces** in your tenant to explore the data being collected.
