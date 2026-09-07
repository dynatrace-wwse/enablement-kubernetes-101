# Section 3 — Restart Application Services

In the previous section your cluster started sending **logs** without you touching the application at all. **Traces are different.** To trace a request, Dynatrace has to run *inside* your application process — and a process can only be instrumented at the moment it starts.

Your `todoapp` has been running since before you deployed the DynaKube, so it started without the agent. Restart it, and the new pods come up instrumented.

## Why a restart is needed

In Application Observability mode there is no OneAgent DaemonSet on your nodes. Instead:

1. Dynatrace registers a **mutating webhook** in your cluster.
2. Every time a pod is *created*, the webhook rewrites its spec to mount the OneAgent code module (delivered by the **CSI driver**) and to load it into the application process.
3. Pods that already existed never passed through that webhook — so they are not instrumented, and never will be until they are recreated.

A rolling restart recreates them, which is all it takes.

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

## Validation — OneAgent injected

The check below verifies that the restarted pods have the `oneagent.dynatrace.com/injected: "true"` annotation set by the mutating webhook. This annotation is the definitive proof that the agent was successfully injected at pod startup.

<!-- LAB_QUESTION
type: shell-verification
question: "Verify OneAgent was injected into the todoapp pods"
buttonText: "Check Injection"
command: "source .devcontainer/util/source_framework.sh >/dev/null 2>&1 && checkOneAgentInjected"
expect:
  operator: exit-zero
hint: "Run `kubectl rollout restart deployment -n todoapp` in the Terminal tab and wait for the rollout to finish, then check again — it looks for the `oneagent.dynatrace.com/injected: true` annotation on the restarted pods."
explanation: "OneAgent injected — the todoapp pods have the `oneagent.dynatrace.com/injected: true` annotation confirming agent injection at startup."
-->



## Use the application

An instrumented application only produces data when someone uses it. So use it — add a todo.

### Step 1 — Open your Todo app and add a task

Go to the workspace, open the Todo app, and add a couple of tasks — the text does not matter. The application is now instrumented, so every one of those requests runs through the injected OneAgent: each click produces a **log line** (the app logs every todo it accepts) and a **trace** (the request runs through an instrumented process).


<!-- LAB_QUESTION
type: shell-verification
question: "Confirm the app accepts a new todo"
buttonText: "Add a todo for me"
command: "source .devcontainer/util/source_framework.sh >/dev/null 2>&1 && generateTodoTraffic"
expect:
  operator: exit-zero
hint: "Needs the todoapp reachable via the ingress. If the endpoint is not answering yet, wait a moment and try again."
explanation: "A todo was created — its log line and its trace should reach Grail within ~2 minutes."
-->



## Verify the log

The app logs each todo it accepts, with the title you typed:

```
com.dynatrace.todoapp.TodoController : Adding a new todo: TodoRecord{title='...'}
```

The `endsWith(k8s.cluster.name, "{{DT_SESSION_ID}}")` filter scopes the query to **your** cluster — every session gets a unique cluster identity ending in your session id, so classmates running this training against the same tenant never pollute your results.

```dql
fetch logs, from:now()-15m
| filter endsWith(k8s.cluster.name, "{{DT_SESSION_ID}}")
| filter k8s.namespace.name == "todoapp"
| filter contains(content, "Adding a new todo")
| fields timestamp, content
| limit 5
```

<!-- LAB_QUESTION
type: dql-verification
question: "Verify the log line for your todo reached Dynatrace Grail"
buttonText: "Check logs in Grail"
dql: |
  fetch logs, from:now()-15m
  | filter endsWith(k8s.cluster.name, "{{DT_SESSION_ID}}")
  | filter k8s.namespace.name == "todoapp"
  | filter contains(content, "Adding a new todo")
  | limit 1
expect:
  operator: not-empty
hint: "Add a todo first (previous step). Logs take ~1–2 minutes to reach Grail — if nothing is found yet, wait a moment and check again."
explanation: "Your todo's log line is in Grail — captured by the log module, with no code change to the application."
-->

## Verify the traces

This is the signal that did **not** exist before the restart. Adding a todo sends a `POST /todos` request, and the injected OneAgent now records it as a distributed trace — a root span named `POST /todos`, resolved to the `addTodo` endpoint of the application.

Notice that the span carries the same Kubernetes context as the log (`k8s.cluster.name`, `k8s.namespace.name`, `k8s.workload.name`). That is metadata enrichment: Dynatrace stitches cluster identity onto the telemetry, which is exactly what lets you scope this query to your own cluster.

```dql
fetch spans, from:now()-15m
| filter endsWith(k8s.cluster.name, "{{DT_SESSION_ID}}")
| filter k8s.namespace.name == "todoapp"
| fields start_time, span.name, endpoint.name, duration, k8s.workload.name
| limit 5
```

<!-- LAB_QUESTION
type: dql-verification
question: "Verify the trace for your todo request reached Dynatrace Grail"
buttonText: "Check traces in Grail"
dql: |
  fetch spans, from:now()-15m
  | filter endsWith(k8s.cluster.name, "{{DT_SESSION_ID}}")
  | filter k8s.namespace.name == "todoapp"
  | limit 1
expect:
  operator: not-empty
pollSeconds: 5
timeoutSeconds: 120
hint: "Traces only exist for pods restarted AFTER the DynaKube was applied — confirm the injection check above passed, then add another todo and wait ~1–2 minutes."
explanation: "The trace is in Grail — the request was recorded from inside the application process, which is what the restart made possible."
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
  the `oneagent.dynatrace.com/injected: "true"` annotation. It also generates traffic so spans are captured.
commands:
  - kubectl rollout restart deployment -n todoapp && kubectl rollout status deployment -n todoapp --timeout=120s && generateTodoTraffic
verify:
  - "source .devcontainer/util/source_framework.sh >/dev/null 2>&1 && checkOneAgentInjected"
-->

## Explore your services in Dynatrace

Now that the application is instrumented, use the Dynatrace Services App to see the automatically discovered services, performance indicators, and distributed traces from the `todoapp` namespace.

[dt-app|dynatrace.services|Open Services App](placeholder)

## Knowledge check

Answer the following questions to complete the training.

<!-- LAB_QUESTIONAIRE: k8s-101-fundamentals retake=false -->

!!! success "Training complete!"
    Your cluster is now fully instrumented with Dynatrace. Head to **Services**, **Kubernetes**, and **Distributed Traces** in your tenant to explore the data being collected.
