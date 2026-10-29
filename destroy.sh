#!/bin/bash
# ==============================================================================
# destroy.sh - Guacamole + Active Directory on GCP: teardown
# ------------------------------------------------------------------------------
#   1. 03-servers: load balancer, Guacamole, Windows and MATE VMs.
#   2. Every image in the guacamole-mate-images family.
#   3. 01-directory: mini-AD, secrets, firewall rules, network.
#
# Notes:
#   - Idempotent: each phase is skipped when there is nothing left to
#     destroy, so a re-run after a partial failure picks up where it stopped.
#   - This permanently deletes everything the lab created.
# ==============================================================================

set -euo pipefail
cd "$(dirname "$0")"

./check_env.sh
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials.json"

# Resources a Terraform directory still tracks (0 when none or no state).
# A failed init (e.g. the provider registry unreachable) stops the script:
# counting it as 0 would skip a phase that still has resources.
tracked() {
  (cd "$1" && terraform init -input=false >/dev/null) ||
    { echo "ERROR: terraform init failed in $1; stopping rather than skipping it. Re-run ./destroy.sh." >&2; return 1; }
  (cd "$1" && terraform state list 2>/dev/null | wc -l)
}

images() {
  gcloud compute images list --filter="family=guacamole-mate-images" \
    --sort-by="~creationTimestamp" --format="value(name)"
}

# ------------------------------------------------------------------------------
# Phase 1: destroy the server layer
# ------------------------------------------------------------------------------
# Its image data source needs a real image name, so look one up while the
# images still exist.
# ------------------------------------------------------------------------------
# Assigned first: set -e ignores a failure inside "[ $(...) ]", but not here.
count=$(tracked 03-servers)
if [ "${count}" -gt 0 ]; then
  echo "NOTE: Destroying the load balancer, Guacamole and servers..."
  mate_image_name=$(images | head -n 1)
  echo "NOTE: Using image: ${mate_image_name}"

  cd 03-servers
  terraform destroy -var="mate_image_name=${mate_image_name}" -auto-approve
  cd ..
else
  echo "NOTE: 03-servers has nothing to destroy; skipping."
fi

# ------------------------------------------------------------------------------
# Phase 2: delete every MATE image (Packer creates them outside Terraform)
# ------------------------------------------------------------------------------
images | while read -r image; do
  echo "NOTE: Deleting image: ${image}"
  gcloud compute images delete "${image}" --quiet
done

# ------------------------------------------------------------------------------
# Phase 3: destroy the directory layer (mini-AD, secrets, network)
# ------------------------------------------------------------------------------
count=$(tracked 01-directory)
if [ "${count}" -gt 0 ]; then
  echo "NOTE: Destroying the mini-AD, secrets and network..."
  cd 01-directory
  terraform destroy -auto-approve
  cd ..
else
  echo "NOTE: 01-directory has nothing to destroy; skipping."
fi

echo "NOTE: Guacamole lab resources have been destroyed."
