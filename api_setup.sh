#!/bin/bash
# ==============================================================================
# api_setup.sh - GCP Authentication and API Enablement
# ------------------------------------------------------------------------------
# Purpose:
#   - Validates presence of service account credentials.json.
#   - Authenticates gcloud using the service account key.
#   - Extracts project_id from the credentials file.
#   - Enables required Google Cloud APIs for this build.
#
# Requirements:
#   - gcloud CLI installed and in PATH.
#   - jq installed for JSON parsing.
#   - credentials.json present in current directory.
#
# Notes:
#   - Script assumes non-interactive automation context.
#   - APIs must be enabled before Terraform can provision resources.
# ==============================================================================

#echo "NOTE: Validating credentials.json and testing gcloud authentication"

# ------------------------------------------------------------------------------
# Validate credentials.json exists
# - Ensures required service account key file is present.
# - Exits immediately if not found.
# ------------------------------------------------------------------------------
if [[ ! -f "./credentials.json" ]]; then
  echo "ERROR: The file './credentials.json' does not exist." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Authenticate using service account key
# - Activates service account for non-interactive CLI usage.
# ------------------------------------------------------------------------------
gcloud auth activate-service-account --key-file="./credentials.json" > /dev/null 2> /dev/null

# ------------------------------------------------------------------------------
# Extract project_id from credentials.json
# - Uses jq to parse JSON.
# - project_id used to set active gcloud project context.
# ------------------------------------------------------------------------------
project_id=$(jq -r '.project_id' "./credentials.json")

# ------------------------------------------------------------------------------
# Enable Required Google Cloud APIs
# - Must be enabled before Terraform resource creation.
# - Some APIs take a few seconds to fully activate.
# ------------------------------------------------------------------------------
echo "NOTE: Enabling APIs needed for build."

gcloud config set project "$project_id"

# Core infrastructure APIs
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

# Storage & secrets
gcloud services enable storage.googleapis.com
gcloud services enable secretmanager.googleapis.com

# Data & file services
gcloud services enable firestore.googleapis.com
gcloud services enable file.googleapis.com