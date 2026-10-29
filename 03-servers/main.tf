# ==============================================================================
# Google Cloud Provider & Local Variables
# ------------------------------------------------------------------------------
# Configures the Google provider using a service account JSON key file.
# Project ID is dynamically extracted from the decoded credentials.
# Locals expose reusable metadata across modules and resources.
# ==============================================================================

provider "google" {
  project     = local.credentials.project_id # Project ID extracted from credentials.json
  credentials = file("../credentials.json")  # Path to service account credentials file
}

# ==============================================================================
# Local Variables
# ------------------------------------------------------------------------------
# Decodes the credentials JSON file for structured reuse.
# Exposes service_account_email for IAM bindings and module inputs.
# ==============================================================================

locals {
  credentials           = jsondecode(file("../credentials.json"))
  service_account_email = local.credentials.client_email
}

# ==============================================================================
# Data Sources: Network and Subnet
# ------------------------------------------------------------------------------
# References existing VPC and subnet resources.
# These are used for instance attachment without recreating network infra.
# ==============================================================================

data "google_compute_network" "ad_vpc" {
  name = var.vpc
}

data "google_compute_subnetwork" "ad_subnet" {
  name   = var.subnet
  region = "us-central1"
}

# ==============================================================================
# Input Variable: MATE Image Name
# ------------------------------------------------------------------------------
# Name of the custom MATE image produced by Packer.
# Used as the boot disk source for GCE instances in this module.
# ==============================================================================

variable "mate_image_name" {
  description = "Name of the Packer-built MATE GCP image"
  type        = string
}

# ==============================================================================
# Data Source: GCE Image Lookup
# ------------------------------------------------------------------------------
# Resolves the custom MATE image by name within the current project.
# Allows downstream resources to reference the image safely by ID/self_link.
# ==============================================================================

data "google_compute_image" "mate_packer_image" {
  name    = var.mate_image_name           # Image name passed in from workflow
  project = local.credentials.project_id # Project containing the image
}