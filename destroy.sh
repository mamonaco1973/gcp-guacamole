#!/bin/bash
# ==============================================================================
# destroy.sh
# ------------------------------------------------------------------------------
# Purpose:
#   - Tear down the GCP MATE environment:
#       01) Destroy servers (Terraform) using the latest MATE image name
#       02) Delete all MATE images from the project (best-effort)
#       03) Destroy directory services (Terraform)
#
# Notes:
#   - Uses the most recently created image in family 'mate-images' whose name
#     matches '^mate-image' as an input to 03-servers Terraform destroy.
#   - Image deletion is best-effort and continues on failures.
# ==============================================================================

#!/bin/bash

# ------------------------------------------------------------------------------
# Determine Latest MATE Image
# ------------------------------------------------------------------------------

mate_image=$(gcloud compute images list \
  --filter="name~'^mate-image' AND family=mate-images" \
  --sort-by="~creationTimestamp" \
  --limit=1 \
  --format="value(name)")  # Grabs most recently created image from 'mate-images' family

if [[ -z "$mate_image" ]]; then
  echo "ERROR: No latest image found for 'mate-image' in family 'mate-images'."
  exit 1  # Hard fail if no image found — we can't safely destroy without this input
fi

echo "NOTE: MATE image is $mate_image"

# ------------------------------------------------------------------------------
# Phase 1: Destroy Servers (Terraform)
# ------------------------------------------------------------------------------

cd 03-servers

terraform init
terraform destroy \
  -var="mate_image_name=$mate_image" \
  -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Phase 2: Delete MATE Images (Best-Effort)
# ------------------------------------------------------------------------------

image_list=$(gcloud compute images list \
  --format="value(name)" \
  --filter="name~'^(mate)'")     # Regex match for names starting with 'mate'

# Check if any were found
if [ -z "$image_list" ]; then
  echo "NOTE: No images found starting with 'mate'. Continuing..."
else
  echo "NOTE: Deleting images..."
  for image in $image_list; do
    echo "NOTE: Deleting image: $image"
    gcloud compute images delete "$image" --quiet || echo "WARNING: Failed to delete image: $image"  # Continue even if deletion fails
  done
fi

# ------------------------------------------------------------------------------
# Phase 3: Destroy Directory Services (Terraform)
# ------------------------------------------------------------------------------

cd 01-directory

terraform init
terraform destroy -auto-approve

cd ..
