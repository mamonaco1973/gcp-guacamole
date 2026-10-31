#!/bin/bash
# ==============================================================================
# validate.sh - Guacamole + Active Directory on GCP: deployment check
# ------------------------------------------------------------------------------
#   - Waits for the load balancer to report the Guacamole server healthy (its
#     setup takes a few minutes after Terraform finishes).
#   - Checks the HTTPS URL answers (self-signed certificate, so curl -k) and
#     that HTTP redirects to it. A new load balancer can take several minutes
#     to start serving, so both wait.
#   - Signs in to Guacamole's API as jsmith -- LDAPS to AD, the mcloud-users
#     group gate -- and checks all three connections are granted.
#   - Checks no VM has a public IP.
#   - Prints the URL and a login. One line per check, then a summary.
# ==============================================================================
set -euo pipefail
cd "$(dirname "$0")"

fail() { echo "FAILED"; echo "ERROR: $*" >&2; exit 1; }
step() { printf '%-58s' "$1..."; }
ok()   { echo "${1:-ok}"; }

out() { terraform -chdir=03-servers output -raw "$1" 2>/dev/null || true; }
URL="$(out guacamole_url)"
BACKEND="$(out backend_service_name)"
GUAC_VM="$(out guacamole_vm_name)"
ZONE="$(out zone)"
[ -n "${URL}" ] || fail "No guacamole_url output. Run ./apply.sh first."

LOG_HINT="gcloud compute ssh ${GUAC_VM} --zone ${ZONE} --tunnel-through-iap --command 'sudo tail -50 /root/userdata.log'"

# ------------------------------------------------------------------------------
# Load balancer backend health (Guacamole's setup: Docker, images, LDAPS trust)
# ------------------------------------------------------------------------------
echo "Guacamole healthy behind the load balancer (up to 15 min)..."
STATE=""
START=${SECONDS}
while :; do
  STATE="$(gcloud compute backend-services get-health "${BACKEND}" --global \
    --format='value(status.healthStatus[0].healthState)' 2>/dev/null || true)"
  ELAPSED=$((SECONDS - START))
  printf "  %02d:%02d  %-49s" $((ELAPSED / 60)) $((ELAPSED % 60)) "backend ${STATE:-not reported yet}"
  if [ "${STATE}" = "HEALTHY" ]; then
    ok
    break
  fi
  echo "waiting"
  ((ELAPSED < 900)) || fail "Backend is '${STATE}'. Setup log: ${LOG_HINT}"
  sleep 15
done

step "HTTPS answers at the load balancer"
CODE=""
for ((i = 0; i < 40; i++)); do
  CODE="$(curl -sk --max-time 15 -o /dev/null -w '%{http_code}' "${URL}" || true)"
  [ "${CODE}" = "200" ] && break
  sleep 15
done
[ "${CODE}" = "200" ] || fail "${URL} answered ${CODE}."
ok

step "HTTP redirects to HTTPS"
LOCATION=""
for ((i = 0; i < 20; i++)); do
  LOCATION="$(curl -s --max-time 15 -o /dev/null -w '%{redirect_url}' "${URL/https:/http:}" || true)"
  # The load balancer spells out the default port (https://<ip>:443/).
  LOCATION="${LOCATION/:443\//\/}"
  [ "${LOCATION}" = "${URL}" ] && break
  sleep 15
done
[ "${LOCATION}" = "${URL}" ] || fail "http:// redirected to '${LOCATION}'."
ok

# ------------------------------------------------------------------------------
# Sign in as an AD user and list the connections Guacamole grants
# ------------------------------------------------------------------------------
JSMITH="$(gcloud secrets versions access latest \
  --secret=jsmith-ad-credentials-guacamole | jq -r .password)"

step "Sign-in as jsmith (LDAPS to AD)"
TOKEN=""
for ((i = 0; i < 12; i++)); do
  TOKEN="$(curl -sk --max-time 15 -X POST "${URL}api/tokens" \
    --data-urlencode "username=jsmith" --data-urlencode "password=${JSMITH}" \
    | jq -r '.authToken // empty' 2>/dev/null || true)"
  [ -n "${TOKEN}" ] && break
  sleep 10
done
[ -n "${TOKEN}" ] || fail "jsmith could not sign in. Check LDAPS from the Guacamole server (cd /opt/guacamole && sudo docker compose logs guacamole)."
ok

step "Connections granted to mcloud-users"
# Retried like the sign-in: right after a user's first LDAPS sign-in the API
# can answer with something other than the connection list.
CONNECTIONS=""
for ((i = 0; i < 12; i++)); do
  CONNECTIONS="$(curl -sk --max-time 15 "${URL}api/session/data/postgresql/connections" \
    -H "Guacamole-Token: ${TOKEN}" \
    | jq -r '[.[].name] | sort | join(", ")' 2>/dev/null || true)"
  [ "${CONNECTIONS}" = "MATE (RDP), MATE (SSH), Windows (RDP)" ] && break
  sleep 10
done
[ "${CONNECTIONS}" = "MATE (RDP), MATE (SSH), Windows (RDP)" ] || fail "Expected three connections, got '${CONNECTIONS}'."
ok "${CONNECTIONS}"
curl -sk -o /dev/null -X DELETE "${URL}api/session" -H "Guacamole-Token: ${TOKEN}" || true

# ------------------------------------------------------------------------------
# Only the load balancer (and Cloud NAT, outbound only) has a public IP
# ------------------------------------------------------------------------------
step "No VM has a public IP"
VM_PIPS="$(gcloud compute instances list --filter="networkInterfaces.network:guacamole-vpc" \
  --format='value(networkInterfaces[].accessConfigs[].natIP)' | tr -d ';[:space:]')"
[ -z "${VM_PIPS}" ] || fail "VMs have public IPs: ${VM_PIPS}"
ok

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
cat <<EOF

Guacamole + Active Directory
============================
URL      : ${URL}
           Self-signed certificate: the browser warns once;
           choose Advanced > Proceed.
Sign in  : jsmith / ${JSMITH}
           (any mcloud-users member; passwords in Secret Manager
           as <user>-ad-credentials-guacamole)
Connect  : Windows (RDP), MATE (RDP desktop) and MATE (SSH),
           as the signed-in user.
EOF
