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

# ─── Temporary: sprint codemodules images are not pullable ────────────────────
#
# On sprint tenants the DynaKube resolves its codemodules image from the TENANT'S
# PRIVATE registry (478983378254.dkr.ecr.us-east-1.amazonaws.com). No paasToken is
# issued for these sessions and no <dynakube>-pull-secret is created, so the CSI
# provisioner's pull goes out unauthenticated and answers:
#
#   401 Unauthorized: Not Authorized
#
# NOTHING is extracted -- /data/codemodules stays completely empty, with no version
# directory at all. installAgentFromImage() swallows the pull failure and returns
# nil, so the only error ever raised is the downstream
#
#   open /data/codemodules/<version>/agent/bin: no such file or directory
#
# from symlink.findVersionFromFileSystem. The provisioner never records the version
# and digest, every oneagent-bin mount is refused from then on, and the learner's
# pod sits in Init forever.
#
# This is NOT the operator 1.10.x link-entry extraction issue: that would leave a
# version directory holding partial contents. There is no archive here because the
# image was never fetched. An earlier workaround setting
# DT_EXTRACT_CODEMODULES_IMAGE_LINKS=true was reverted -- it changes how an archive
# is unpacked and cannot help when the pull itself is refused.
#
# Fix: pin spec.oneAgent.applicationMonitoring.codeModulesImage to the newest PUBLIC
# build, which pulls anonymously. The framework's fixSprintActiveGateImage already
# does exactly this for the ActiveGate image, for exactly this reason.
#
# Delete this once sprint sessions get a working pull secret -- the tenant's own,
# newer codemodules image is preferable when it can actually be pulled.
latestPublicCodeModulesImage() {
  # Echo the newest pullable ref on public.ecr.aws/dynatrace/dynatrace-codemodules,
  # or return non-zero if it cannot be resolved (offline / API change).
  #
  # Only PLAIN N.N.N.N-N tags. The repository also publishes single-language
  # variants (-java, -python, -nodejs, -php) which sort adjacent to the multi-arch
  # tag and must never be selected -- picking one would instrument only that runtime.
  local repo="public.ecr.aws/dynatrace/dynatrace-codemodules" token tag
  token="$(curl -fsS https://public.ecr.aws/token/ 2>/dev/null | jq -r '.token // empty')" || return 1
  [ -n "$token" ] || return 1
  tag="$(curl -fsS -H "Authorization: Bearer $token" \
        "https://public.ecr.aws/v2/dynatrace/dynatrace-codemodules/tags/list" 2>/dev/null \
        | jq -r '.tags[]?' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$' | sort -V | tail -1)"
  [ -n "$tag" ] || return 1
  echo "${repo}:${tag}"
}

fixSprintCodeModulesImage() {
  # Post-apply patch: needs a DynaKube to already exist, so it runs AFTER the
  # deploy (unlike the reverted workaround, which patched workloads beforehand).
  # Best-effort throughout -- never fails the lab step it is called from.
  isSprintTenant || return 0

  local dk
  dk="$(kubectl get dynakube -n dynatrace --no-headers 2>/dev/null | awk '{print $1}' | head -1)"
  if [ -z "$dk" ]; then
    printWarn "No DynaKube found — nothing to pin"
    return 0
  fi

  # Already pinned? Skip, and keep the log honest about what happened.
  local current
  current="$(kubectl -n dynatrace get dynakube "$dk" \
    -o jsonpath='{.spec.oneAgent.applicationMonitoring.codeModulesImage}' 2>/dev/null)"
  case "$current" in
    public.ecr.aws/*)
      printInfo "codeModulesImage already pinned to $current — nothing to do"
      return 0
      ;;
  esac

  local img
  if ! img="$(latestPublicCodeModulesImage)"; then
    printWarn "Could not resolve a public codemodules image — leaving the default."
    return 0
  fi

  printWarn "Sprint codemodules images are not pullable (401 from the tenant's private registry) — pinning the latest public build."
  printInfo "Pinning codeModulesImage to $img"
  kubectl -n dynatrace patch dynakube "$dk" --type=merge \
    -p "{\"spec\":{\"oneAgent\":{\"applicationMonitoring\":{\"codeModulesImage\":\"$img\"}}}}" >/dev/null 2>&1 \
    || printWarn "Could not patch the DynaKube (continuing)"
  return 0
}
