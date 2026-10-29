# ==============================================================================
# mate.pkr.hcl -- Ubuntu 26.04 + Ubuntu MATE core + XRDP + SSSD packages
# ==============================================================================
# Builds the image for the private desktop host that Guacamole reaches over
# RDP and SSH. The image holds the slow, generic part (desktop, XRDP, Firefox,
# the SSSD/realmd packages). The domain join happens at boot in the startup
# script (03-servers/scripts/startup_mate.sh): a computer account and keytab
# are per machine and must never be baked into a shared image.
#
# Packer builds in the project's default network with a temporary public IP,
# so the build does not depend on the phase-1 network.
# ==============================================================================

packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1.1.6"
    }
  }
}

# ------------------------------------------------------------------------------
# Locals: Timestamp Utility
# - Generates compact timestamp for image naming
# ------------------------------------------------------------------------------
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

# ------------------------------------------------------------------------------
# Input Variables
# ------------------------------------------------------------------------------
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
  description = "Base GCP image family"
  type        = string
  default     = "ubuntu-2604-lts-amd64"
}

# ------------------------------------------------------------------------------
# Source Block: GCE Image Builder
# ------------------------------------------------------------------------------
source "googlecompute" "mate_image" {
  project_id          = var.project_id
  zone                = var.zone
  source_image_family = var.source_image_family
  ssh_username        = "ubuntu"
  machine_type        = "e2-standard-4"

  image_name    = "guacamole-mate-image-${local.timestamp}"
  image_family  = "guacamole-mate-images"
  disk_size     = 30
  state_timeout = "30m" # Image registration can exceed the 5m default
}

# ------------------------------------------------------------------------------
# Build Block: Provisioning Scripts
# - Executes each setup script inside the build VM
# ------------------------------------------------------------------------------
build {
  sources = ["source.googlecompute.mate_image"]

  provisioner "shell" {
    script          = "./scripts/01-packages.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  provisioner "shell" {
    script          = "./scripts/02-desktop.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  provisioner "shell" {
    script          = "./scripts/03-xrdp.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }
}
