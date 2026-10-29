#!/bin/bash
# ==============================================================================
# apply.sh - Guacamole + Active Directory on GCP: build
# ------------------------------------------------------------------------------
# Three phases:
#   1. 01-directory: VPC, firewall rules, Cloud NAT, secrets, mini-AD.
#   2. 02-packer:    the MATE + XRDP image.
#   3. 03-servers:   the load balancer, Guacamole, and the Windows and MATE
#                    servers.
# Then validate.sh checks the result.
#
# Notes:
#   - ./credentials.json (a service account key) must be in the repo root.
#   - Each run builds a fresh image; phase 3 uses the newest one, and
#     destroy.sh deletes them all.
# ==============================================================================

set -euo pipefail
cd "$(dirname "$0")"

# ------------------------------------------------------------------------------
# Pre-flight check: tools, credentials.json, gcloud login, APIs
# ------------------------------------------------------------------------------
./check_env.sh
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials.json"
project_id=$(jq -r '.project_id' ./credentials.json)

# ------------------------------------------------------------------------------
# Phase 1: directory layer (network, firewall, secrets, mini-AD)
# ------------------------------------------------------------------------------
echo "NOTE: Building the network, secrets and mini-AD..."
cd 01-directory
terraform init
terraform apply -auto-approve
cd ..

# ------------------------------------------------------------------------------
# Phase 2: MATE image (Packer builds in the project's default network)
# ------------------------------------------------------------------------------
echo "NOTE: Building the MATE + XRDP image with Packer..."
cd 02-packer
packer init .
packer build -var="project_id=${project_id}" mate.pkr.hcl
cd ..

# ------------------------------------------------------------------------------
# Phase 3: load balancer, Guacamole and the servers
# ------------------------------------------------------------------------------
mate_image_name=$(gcloud compute images list \
  --filter="family=guacamole-mate-images" \
  --sort-by="~creationTimestamp" --limit=1 \
  --format="value(name)")
if [ -z "${mate_image_name}" ]; then
  echo "ERROR: No image found in family guacamole-mate-images."
  exit 1
fi
echo "NOTE: Using latest MATE image: ${mate_image_name}"

echo "NOTE: Building the load balancer, Guacamole and servers..."
cd 03-servers
terraform init
terraform apply -var="mate_image_name=${mate_image_name}" -auto-approve
cd ..

# ------------------------------------------------------------------------------
# Build validation
# ------------------------------------------------------------------------------
echo "NOTE: Running build validation..."
./validate.sh

echo "NOTE: Infrastructure build complete."
