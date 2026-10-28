#!/bin/bash
# ======================================================================
#          ------- Custom Functions -------                            #
#  Space for adding custom functions so each repo can customize as.    #
#  needed.                                                             #
# ======================================================================


customFunction(){
  printInfoSection "This is a custom function that calculates 1 + 1"

  printInfo "1 + 1 = $(( 1 + 1 ))"

}

# ======================================================================
#   Step-by-step verification helpers
# ----------------------------------------------------------------------
#   Called from the lab pages' `shell-verification` blocks by name alone
#   (the platform sources the framework before every check).
#
#   Learner clicks answer INSTANTLY: one probe, immediate pass/fail with
#   a clear message — never a spinner while the check retries.
#
#   Automation (lab-driver, agentic validator, solution runs) exports
#   LAB_WAIT=1 first: the check then waits for the expected state before
#   probing — using the framework wait function bound to that resource
#   where one exists (waitForPod, waitForAllReadyPods) — so verifying a
#   step right after running its solution doesn't race the rollout.
#
#   The waitFor* names are kept as LAB_WAIT wrappers so already-imported
#   lab content and published docs keep working during the transition.
# ======================================================================

# Cluster node is Ready.
checkNodeReady() {
  if [ -n "${LAB_WAIT:-}" ]; then
    local i=0
    while [ "$i" -lt 18 ]; do
      [ "$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready')" -gt 0 ] && break
      i=$((i + 1)); printInfo "node not Ready yet ($i/18), waiting 5s"; sleep 5
    done
  fi
  if [ "$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready')" -gt 0 ]; then
    printInfo "Cluster node is Ready"; return 0
  fi
  printError "Cluster node is not Ready yet"; return 1
}
waitForNodeReady() { LAB_WAIT=1 checkNodeReady; }

# TODO app pods are Running in the todoapp namespace.
checkTodoAppRunning() {
  [ -n "${LAB_WAIT:-}" ] && waitForAllReadyPods todoapp
  if [ "$(kubectl get pods -n todoapp --no-headers 2>/dev/null | grep -c Running)" -gt 0 ]; then
    printInfo "todoapp pods are Running"; return 0
  fi
  printError "todoapp pods are not Running yet — the environment may still be starting"; return 1
}
waitForTodoAppRunning() { LAB_WAIT=1 checkTodoAppRunning; }

# Dynatrace Operator manager pod is Running (Section 1).
checkOperatorReady() {
  [ -n "${LAB_WAIT:-}" ] && waitForPod dynatrace operator
  if kubectl get pods -n dynatrace --no-headers 2>/dev/null | grep -E 'operator' | grep -q Running; then
    printInfo "Dynatrace Operator pod is Running"; return 0
  fi
  printError "Dynatrace Operator is not running — run the Helm install steps above, then check again"; return 1
}
waitForOperatorReady() { LAB_WAIT=1 checkOperatorReady; }

# DynaKube custom resource exists (Section 2).
checkDynakube() {
  if [ -n "${LAB_WAIT:-}" ]; then
    local i=0
    while [ "$i" -lt 30 ]; do
      kubectl get dynakube -n dynatrace --no-headers 2>/dev/null | grep -q . && break
      i=$((i + 1)); printInfo "no DynaKube yet ($i/30), waiting 5s"; sleep 5
    done
  fi
  if kubectl get dynakube -n dynatrace --no-headers 2>/dev/null | grep -q .; then
    printInfo "DynaKube custom resource is present"; return 0
  fi
  printError "No DynaKube found in the dynatrace namespace — apply the generated manifest, then check again"; return 1
}
waitForDynakube() { LAB_WAIT=1 checkDynakube; }

# LAB_WAIT helper: poll until a pod matching <pattern> in <namespace> is Running.
# The framework's waitForPod only waits until the pod EXISTS (Pending and
# ContainerCreating count), so the Running probe right after it still raced the
# rollout. Returns instead of `exit`ing (waitForPod exits the caller's shell).
_waitPodRunning() {
  local ns="$1" pattern="$2" tries="${3:-36}" i=0
  while [ "$i" -lt "$tries" ]; do
    kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -i "$pattern" | grep -q Running && return 0
    i=$((i + 1)); printInfo "$pattern not Running yet ($i/$tries), waiting 10s"; sleep 10
  done
  return 1
}

# ActiveGate pod is Running in the dynatrace namespace (Section 2).
checkActiveGateReady() {
  [ -n "${LAB_WAIT:-}" ] && _waitPodRunning dynatrace activegate
  if kubectl get pods -n dynatrace --no-headers 2>/dev/null | grep -i activegate | grep -q Running; then
    printInfo "ActiveGate pod is Running"; return 0
  fi
  printError "ActiveGate pod is not Running yet — it can take a minute or two after the DynaKube is applied; check again shortly"; return 1
}
waitForActiveGateReady() { LAB_WAIT=1 checkActiveGateReady; }

# OneAgent injection annotation present on the restarted todoapp pods (Section 3).
checkOneAgentInjected() {
  if [ -n "${LAB_WAIT:-}" ]; then
    local i=0
    while [ "$i" -lt 24 ]; do
      kubectl get pods -n todoapp -o jsonpath='{.items[*].metadata.annotations.oneagent\.dynatrace\.com/injected}' 2>/dev/null | tr ' ' '\n' | grep -q true && break
      i=$((i + 1)); printInfo "not injected yet ($i/24), waiting 10s"; sleep 10
    done
  fi
  if kubectl get pods -n todoapp -o jsonpath='{.items[*].metadata.annotations.oneagent\.dynatrace\.com/injected}' 2>/dev/null | tr ' ' '\n' | grep -q true; then
    printInfo "OneAgent is injected into the todoapp pods"; return 0
  fi
  printError "OneAgent injection annotation not present — restart the todoapp deployment and wait for the rollout, then check again"; return 1
}
waitForOneAgentInjected() { LAB_WAIT=1 checkOneAgentInjected; }

# Dynatrace log module pod is Running (Section 2).
# Container logs are captured by the log monitoring DaemonSet (pods named
# <dynakube>-logmonitoring, image dynatrace-logmodule), which the
# operator rolls out from the DynaKube's `logMonitoring` section. It tails
# container stdout — no pod restart and no code injection are involved, which is
# exactly the point Section 2 makes.
checkLogModuleReady() {
  [ -n "${LAB_WAIT:-}" ] && _waitPodRunning dynatrace logmonitoring
  if kubectl get pods -n dynatrace --no-headers 2>/dev/null | grep -i logmonitoring | grep -q Running; then
    printInfo "Dynatrace log module is Running — your cluster's container logs are being captured"; return 0
  fi
  if kubectl get dynakube -n dynatrace --no-headers 2>/dev/null | grep -q . \
    && ! kubectl get dynakube -n dynatrace -o jsonpath='{.items[*].spec.logMonitoring}' 2>/dev/null | grep -q .; then
    printError "The applied DynaKube has no logMonitoring section, so no log module will ever start — re-apply .devcontainer/yaml/gen/dynakube.yaml (or Run solution)"; return 1
  fi
  printError "Log module pod is not Running yet — it starts shortly after the DynaKube is applied; check again in a moment"; return 1
}
waitForLogModuleReady() { LAB_WAIT=1 checkLogModuleReady; }

# ======================================================================
#   Section 2 — DynaKube generation and deploy, safe to run concurrently
# ----------------------------------------------------------------------
#   The step's STEP_SETUP generates the DynaKube silently when the learner
#   enters the step, and "Run solution" generated it AGAIN (the framework's
#   deployApplicationMonitoring). Both wrote .devcontainer/yaml/gen/dynakube.yaml
#   in place: the framework's generateDynakube writes the main body first,
#   then looks up image tags in ECR for a few seconds, and only then appends
#   `templates.logMonitoring` and `logMonitoring: {}`. A `kubectl apply` during
#   that window applies a perfectly valid DynaKube WITHOUT the log module (the
#   webhook accepts it), and two generations at once interleave into YAML that
#   does not parse. Clicking "Run solution" right after entering the step hits
#   exactly that window.
#
#   generateDynakubeAtomic writes into a private directory and renames the
#   finished file into place, so a reader only ever sees a complete manifest,
#   and refuses to publish one without logMonitoring. deployDynakube is the
#   solution path: generate atomically, apply, then wait for the log module.
# ======================================================================

generateDynakubeAtomic() {
  local gen_dir="$REPO_PATH/.devcontainer/yaml/gen" tmp rc
  mkdir -p "$gen_dir" || return 1
  # Same filesystem as the target, so the final mv is an atomic rename.
  tmp="$(mktemp -d "$gen_dir/.tmp.XXXXXX")" || return 1
  mkdir -p "$tmp/.devcontainer/yaml"
  # loadDynakubeConfig reads the repo overrides from $REPO_PATH and the defaults
  # from ${FRAMEWORK_CACHE:-$REPO_PATH}; carry both over before switching REPO_PATH.
  cp "$REPO_PATH"/.devcontainer/yaml/dynakube-*.yaml "$tmp/.devcontainer/yaml/" 2>/dev/null
  (
    export FRAMEWORK_CACHE="${FRAMEWORK_CACHE:-$REPO_PATH}"
    REPO_PATH="$tmp"
    generateDynakube "$@"
  )
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q '^  logMonitoring:' "$tmp/.devcontainer/yaml/gen/dynakube.yaml" 2>/dev/null; then
    printError "Generated DynaKube has no logMonitoring section — not publishing it"
    rc=1
  fi
  [ "$rc" -eq 0 ] && mv -f "$tmp/.devcontainer/yaml/gen/dynakube.yaml" "$gen_dir/dynakube.yaml"
  rc=$?
  rm -rf "$tmp"
  return "$rc"
}

# Section 2's LAB_SOLUTION: the AppOnly + log-ingest DynaKube, applied, with
# the ActiveGate and the log module Running before it returns.
deployDynakube() {
  dynatraceEvalReadSaveCredentials
  if [ -z "${DT_TENANT}" ]; then
    printError "No Dynatrace credentials found — cannot deploy the DynaKube"; return 1
  fi
  generateDynakubeAtomic apponly || return 1
  kubectl -n dynatrace wait pod --for=condition=ready \
    --selector=app.kubernetes.io/name=dynatrace-operator,app.kubernetes.io/component=webhook \
    --timeout=300s || { printError "Dynatrace webhook is not ready — deploy the Operator (Section 1) first"; return 1; }
  kubectl -n dynatrace apply -f "$REPO_PATH/.devcontainer/yaml/gen/dynakube.yaml" || return 1
  fixSprintActiveGateImage
  fixSprintCodeModulesImage
  LAB_WAIT=1 checkActiveGateReady || return 1
  LAB_WAIT=1 checkLogModuleReady
}

# Create a TODO via the app's HTTP API (the same curl path the live-debugger lab
# uses). The learner normally does this by hand in the app UI with any text they
# like; this function is the automation equivalent — it backs the step's
# LAB_SOLUTION and the nightly training-test, neither of which can click a web UI.
#
# The title is fixed on purpose: the app logs it verbatim as
#   TodoController : Adding a new todo: TodoRecord{title='...'}
# and the verification DQL matches "Adding a new todo", so the hand-typed and the
# automated path produce the same evidence. A random nonce bought nothing — the
# DQL never matched it, only the query's time window separated runs.
#
# Always waits for the endpoint first (TODO_TRAFFIC_WAIT seconds, default 60;
# 150 with LAB_WAIT=1): a finished `kubectl rollout status` only means the
# container started, and the app answers HTTP some seconds later. Without the
# wait, Section 3's "restart && rollout status && generateTodoTraffic" solution
# raced the rollout and failed although every check passed by hand (ENH-063 F-3).
# Same logic as the framework's generateTodoTraffic (1.12.0+).
generateTodoTraffic() {
  local title="${1:-Kubernetes 101}"
  local url="http://localhost:${K3D_LB_HTTP_PORT:-80}"
  local host="todoapp.$(detectHostname)"
  local wait_s="${TODO_TRAFFIC_WAIT:-60}"
  [ -n "${LAB_WAIT:-}" ] && [ -z "${TODO_TRAFFIC_WAIT:-}" ] && wait_s=150
  local step=5 waited=0
  printInfoSection "Creating a TODO so logs and traces reach Grail"
  printInfo "title: $title  | endpoint: $url (Host: $host)"

  until curl -sf -o /dev/null --max-time 5 -H "Host: $host" "$url/todos"; do
    if [ "$waited" -ge "$wait_s" ]; then
      printError "todoapp HTTP endpoint did not answer within ${wait_s}s — make sure the app is running (checkTodoAppRunning), then try again"
      return 1
    fi
    printInfo "app endpoint not answering yet (${waited}s/${wait_s}s), waiting ${step}s"
    sleep "$step"; waited=$((waited + step))
  done

  local resp
  resp=$(curl -s --max-time 10 -H "Host: $host" -X POST "$url/todos" -H "Content-Type: application/json" \
    -d "{\"title\":\"$title\",\"completed\":false}")
  if echo "$resp" | grep -q '"status":"ok"'; then
    printInfo "Created TODO \"$title\" — its log and its POST /todos trace should appear in Grail within ~2 min"
    return 0
  fi
  printError "Failed to create the TODO. Response: $resp"
  return 1
}
