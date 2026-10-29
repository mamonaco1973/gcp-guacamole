# ==============================================================================
# Google Cloud Provider Configuration
# ------------------------------------------------------------------------------
# Configures the Google provider using a service account key file.
# The credentials file is loaded from a relative path outside this module.
# Project ID is dynamically extracted from the decoded JSON credentials.
# ==============================================================================

provider "google" {
  project     = local.credentials.project_id # Project ID from decoded credentials
  credentials = file("../credentials.json")  # Path to service account JSON
}

# ==============================================================================
# Local Variables
# ------------------------------------------------------------------------------
# Decodes the service account JSON for reuse across the configuration.
# Exposes the service account email for IAM bindings and module inputs.
# ==============================================================================

locals {
  credentials           = jsondecode(file("../credentials.json"))
  service_account_email = local.credentials.client_email
}