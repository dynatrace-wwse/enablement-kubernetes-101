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
#   Step-by-step end-to-end verification helpers
# ----------------------------------------------------------------------
#   Called from the lab pages' `shell-verification` blocks (source the
#   framework first, then call the function). Each Kubernetes/Dynatrace
#   action is asynchronous, so every helper WAITS (bounded retry) for the
#   expected state instead of checking once — this lets the Enablement App
#   (and the app-layer-test driver) verify a step right after the previous
#   one without racing the rollout.
# ======================================================================

# Cluster node reaches Ready.
waitForNodeReady() {
  printInfoSection "Waiting for the cluster node to be Ready"
  local i=0
  while [ "$i" -lt 18 ]; do
    [ "$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready')" -gt 0 ] && { printInfo "node Ready"; return 0; }
    i=$((i + 1)); printInfo "node not Ready yet ($i/18), waiting 5s"; sleep 5
  done
  printError "Cluster node not Ready in time"; return 1
}

# TODO app pods reach Running in the todoapp namespace.
waitForTodoAppRunning() {
  printInfoSection "Waiting for the todoapp pods to be Running"
  local i=0
  while [ "$i" -lt 30 ]; do
    [ "$(kubectl get pods -n todoapp --no-headers 2>/dev/null | grep -c Running)" -gt 0 ] && { printInfo "todoapp Running"; return 0; }
    i=$((i + 1)); printInfo "todoapp not Running yet ($i/30), waiting 5s"; sleep 5
  done
  printError "todoapp pods not Running in time"; return 1
}

# Dynatrace Operator manager pod reaches Running (Section 1).
waitForOperatorReady() {
  printInfoSection "Waiting for the Dynatrace Operator pod to be Running"
  local i=0
  while [ "$i" -lt 36 ]; do
    kubectl get pods -n dynatrace --no-headers 2>/dev/null | grep -E 'operator' | grep -q Running && { printInfo "operator Running"; return 0; }
    i=$((i + 1)); printInfo "operator not Running yet ($i/36), waiting 5s"; sleep 5
  done
  printError "Dynatrace Operator pod not Running in time"; return 1
}

# DynaKube custom resource exists (Section 2).
waitForDynakube() {
  printInfoSection "Waiting for the DynaKube custom resource"
  local i=0
  while [ "$i" -lt 30 ]; do
    kubectl get dynakube -n dynatrace --no-headers 2>/dev/null | grep -q . && { printInfo "DynaKube present"; return 0; }
    i=$((i + 1)); printInfo "no DynaKube yet ($i/30), waiting 5s"; sleep 5
  done
  printError "DynaKube custom resource not found in time"; return 1
}

# ActiveGate pod reaches Running in the dynatrace namespace (Section 2).
waitForActiveGateReady() {
  printInfoSection "Waiting for the ActiveGate pod to be Running"
  local i=0
  while [ "$i" -lt 36 ]; do
    kubectl get pods -n dynatrace --no-headers 2>/dev/null | grep -i activegate | grep -q Running && { printInfo "ActiveGate Running"; return 0; }
    i=$((i + 1)); printInfo "ActiveGate not Running yet ($i/36), waiting 10s"; sleep 10
  done
  printError "ActiveGate pod not Running in time"; return 1
}

# OneAgent injection annotation present on the restarted todoapp pods (Section 3).
waitForOneAgentInjected() {
  printInfoSection "Waiting for the OneAgent injection annotation on todoapp pods"
  local i=0
  while [ "$i" -lt 24 ]; do
    if kubectl get pods -n todoapp -o jsonpath='{.items[*].metadata.annotations.oneagent\.dynatrace\.com/injected}' 2>/dev/null | tr ' ' '\n' | grep -q true; then
      printInfo "OneAgent injected"; return 0
    fi
    i=$((i + 1)); printInfo "not injected yet ($i/24), waiting 10s"; sleep 10
  done
  printError "OneAgent injection annotation not present in time"; return 1
}

# Tag that distinguishes THIS test's TODO log from every other todo log in Grail.
TODO_PROBE_TAG="K8S101LOGPROBE"

# Generate a uniquely-tagged log line by creating a TODO via the app's HTTP API
# (same curl path as the live-debugger lab). The tag (TODO_PROBE_TAG + a per-run
# nonce) is what the Grail DQL matches, so no other todo activity interferes.
# Waits for the app HTTP endpoint to answer first (ingress + app startup take time).
generateTodoTraffic() {
  local nonce="${TODO_PROBE_TAG}-$(date +%s)-${RANDOM}"
  local url="http://localhost:${K3D_LB_HTTP_PORT:-80}"
  local host="todoapp.$(detectHostname)"
  printInfoSection "Generating a uniquely-tagged TODO to verify logs reach Grail"
  printInfo "tag: $nonce  | endpoint: $url (Host: $host)"

  local i=0 reachable=1
  while [ "$i" -lt 30 ]; do
    if curl -sf -o /dev/null -H "Host: $host" "$url/todos"; then reachable=0; break; fi
    i=$((i + 1)); printInfo "app endpoint not ready ($i/30), waiting 5s"; sleep 5
  done
  [ "$reachable" -ne 0 ] && { printError "todoapp HTTP endpoint not reachable"; return 1; }

  local resp
  resp=$(curl -s -H "Host: $host" -X POST "$url/todos" -H "Content-Type: application/json" \
    -d "{\"title\":\"$nonce\",\"completed\":false}")
  if echo "$resp" | grep -q '"status":"ok"'; then
    printInfo "Created tagged TODO: $nonce — its log should appear in Grail within ~2 min"
    return 0
  fi
  printError "Failed to create tagged TODO. Response: $resp"
  return 1
}
