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
#   Called from the lab pages' `shell-verification` blocks (source the
#   framework first, then call the function).
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

# ActiveGate pod is Running in the dynatrace namespace (Section 2).
checkActiveGateReady() {
  [ -n "${LAB_WAIT:-}" ] && waitForPod dynatrace activegate
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
  [ -n "${LAB_WAIT:-}" ] && waitForPod dynatrace logmonitoring
  if kubectl get pods -n dynatrace --no-headers 2>/dev/null | grep -i logmonitoring | grep -q Running; then
    printInfo "Dynatrace log module is Running — your cluster's container logs are being captured"; return 0
  fi
  printError "Log module pod is not Running yet — it starts shortly after the DynaKube is applied; check again in a moment"; return 1
}
waitForLogModuleReady() { LAB_WAIT=1 checkLogModuleReady; }

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
# Learner click: single attempt, fail fast if the endpoint isn't up.
# LAB_WAIT=1 (automation): waits for the endpoint first (ingress + app startup).
generateTodoTraffic() {
  local title="Kubernetes 101"
  local url="http://localhost:${K3D_LB_HTTP_PORT:-80}"
  local host="todoapp.$(detectHostname)"
  printInfoSection "Creating a TODO so logs and traces reach Grail"
  printInfo "title: $title  | endpoint: $url (Host: $host)"

  if [ -n "${LAB_WAIT:-}" ]; then
    local i=0
    while [ "$i" -lt 30 ]; do
      curl -sf -o /dev/null -H "Host: $host" "$url/todos" && break
      i=$((i + 1)); printInfo "app endpoint not ready ($i/30), waiting 5s"; sleep 5
    done
  fi
  if ! curl -sf -o /dev/null -H "Host: $host" "$url/todos"; then
    printError "todoapp HTTP endpoint not reachable yet — make sure the app is running, then try again"
    return 1
  fi

  local resp
  resp=$(curl -s -H "Host: $host" -X POST "$url/todos" -H "Content-Type: application/json" \
    -d "{\"title\":\"$title\",\"completed\":false}")
  if echo "$resp" | grep -q '"status":"ok"'; then
    printInfo "Created TODO \"$title\" — its log and its POST /todos trace should appear in Grail within ~2 min"
    return 0
  fi
  printError "Failed to create the TODO. Response: $resp"
  return 1
}
