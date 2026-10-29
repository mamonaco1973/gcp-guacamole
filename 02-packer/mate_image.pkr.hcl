# ==============================================================================
# PACKER BUILD: MATE Image for GCP (Ubuntu 26.04 LTS)
# ------------------------------------------------------------------------------
# Purpose:
#   - Builds a custom Google Compute Engine image with MATE + XRDP
#   - Starts from the Canonical Ubuntu 26.04 LTS image family
#   - Installs desktop environment, browsers, dev tools, and utilities
#   - Publishes a timestamped image into an image family for reuse in GCE
# ==============================================================================

packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1.1.6"
    }
  }
}

# ==============================================================================
# LOCALS: TIMESTAMP UTILITY
# ==============================================================================

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "") # Compact timestamp (YYYYMMDDHHMMSS)
  # Used to generate unique image names
}

# ==============================================================================
# INPUT VARIABLES
# ==============================================================================

variable "project_id" {
  description = "GCP project ID that will own the image"
  type        = string
}

variable "zone" {
  description = "GCP zone used for the temporary build VM"
  type        = string
  default     = "us-central1-a"
}

variable "source_image_family" {
  description = "Base GCP image family (e.g., ubuntu-2604-lts-amd64)"
  type        = string
  default     = "ubuntu-2604-lts-amd64"
}

# ==============================================================================
# SOURCE: GCE IMAGE BUILDER
# ==============================================================================

source "googlecompute" "mate_image" {
  project_id          = var.project_id
  zone                = var.zone
  source_image_family = var.source_image_family # Base Ubuntu 26.04 LTS image family
  ssh_username        = "ubuntu"                # Default Ubuntu user on GCE images
  machine_type        = "n2-standard-4"         # Temporary build VM machine type

  image_name    = "mate-image-${local.timestamp}" # Unique image name per build
  image_family  = "mate-images"                   # Image family for versioned builds
  disk_size     = 64                              # Boot disk size (GB) for build VM
  state_timeout = "30m"                           # Image registration can exceed the 5m default
}

# ==============================================================================
# BUILD: PROVISIONING SCRIPTS
# ------------------------------------------------------------------------------
# Executes each setup script inside the temporary build VM. Each script should be
# idempotent and safe to re-run during iterative development.
# ==============================================================================

build {
  sources = ["source.googlecompute.mate_image"]

  # ----------------------------------------------------------------------------
  # Base OS packages and prerequisites
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./packages.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # MATE desktop environment
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./mate.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # XRDP remote desktop services and session configuration
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./xrdp.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # Google Chrome browser installation
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./chrome.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # Firefox browser installation/configuration
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./firefox.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # Visual Studio Code installation/configuration
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./vscode.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # HashiCorp CLI tools (e.g., Terraform, Packer)
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./hashicorp.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # AWS CLI installation (optional multi-cloud tooling)
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./awscli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # Azure CLI installation (optional multi-cloud tooling)
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./azcli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # Google Cloud CLI installation (gcloud)
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./gcloudcli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # Docker Engine installation/configuration
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./docker.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # Postman installation
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./postman.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # KRDC (KDE Remote Desktop Client) installation
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./krdc.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # OnlyOffice installation
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./onlyoffice.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # ----------------------------------------------------------------------------
  # Desktop defaults and trusted launcher icons (/etc/skel)
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    script          = "./desktop.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }
}
