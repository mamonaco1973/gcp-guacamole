# ==============================================================================
# Random Suffix, Firewall Rules, and MATE Desktop VM
# ------------------------------------------------------------------------------
# Provisions:
#   1. Random suffix for globally unique resource naming.
#   2. Firewall rules for SSH and SMB access (lab scope).
#   3. Ubuntu 26.04 MATE VM acting as AD-joined NFS gateway client.
#   4. Ubuntu image lookup for latest 26.04 LTS reference.
#
# Notes:
#   - SSH/SMB rules are open to 0.0.0.0/0 (lab only).
#   - VM boots from custom Packer-built MATE image.
#   - Startup script handles AD join and NFS mount.
# ==============================================================================


# ==============================================================================
# Random String Generator
# ------------------------------------------------------------------------------
# Generates a lowercase alphanumeric suffix for unique VM naming.
# Prevents collisions across repeated or parallel deployments.
# ==============================================================================

resource "random_string" "vm_suffix" {
  length  = 10    # Length of generated suffix
  special = false # Exclude special characters
  upper   = false # Lowercase only
}


# ==============================================================================
# Firewall Rule: Allow SSH
# ------------------------------------------------------------------------------
# Allows inbound TCP/22 to instances tagged with "allow-ssh".
# Source range is open to the internet (restrict in production).
# ==============================================================================

resource "google_compute_firewall" "allow_ssh" {
  name    = "mate-allow-ssh"
  network = var.vpc

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["mate-allow-ssh"]
  source_ranges = ["0.0.0.0/0"]
}


# ==============================================================================
# Firewall Rule: Allow SMB
# ------------------------------------------------------------------------------
# Allows inbound TCP/445 to instances tagged with "allow-smb".
# Intended for Windows file sharing access (lab scope only).
# ==============================================================================

resource "google_compute_firewall" "allow_smb" {
  name    = "mate-allow-smb"
  network = var.vpc

  allow {
    protocol = "tcp"
    ports    = ["445"]
  }

  target_tags   = ["mate-allow-smb"]
  source_ranges = ["0.0.0.0/0"]
}


# ==============================================================================
# MATE VM: AD-Joined Desktop + NFS Gateway Client
# ------------------------------------------------------------------------------
# Deploys a MATE 26.04 VM that:
#   - Attaches to ad-vpc and ad-subnet.
#   - Boots from a Packer-built custom image.
#   - Executes startup script to join AD and mount NFS storage.
#   - Uses OS Login and a service account for secure access.
# ==============================================================================

resource "google_compute_instance" "desktop_instance" {
  name         = "mate-${random_string.vm_suffix.result}"
  machine_type = "n2-standard-4"
  zone         = "us-central1-a"

  # ----------------------------------------------------------------------------
  # Boot Disk
  # ----------------------------------------------------------------------------
  boot_disk {
    initialize_params {
      image = data.google_compute_image.mate_packer_image.self_link
    }
  }

  # ----------------------------------------------------------------------------
  # Network Interface
  # ----------------------------------------------------------------------------
  network_interface {
    network    = var.vpc
    subnetwork = var.subnet

    access_config {}
  }

  # ----------------------------------------------------------------------------
  # Metadata (Startup Script + OS Login)
  # ----------------------------------------------------------------------------
  metadata = {
    enable-oslogin = "TRUE"

    startup-script = templatefile("./scripts/nfs_gateway_init.sh", {
      domain_fqdn   = var.dns_zone
      nfs_server_ip = google_filestore_instance.nfs_server.networks[0].ip_addresses[0]
      netbios       = var.netbios
      force_group   = "mcloud-users"
      realm         = var.realm
    })
  }

  # ----------------------------------------------------------------------------
  # Service Account
  # ----------------------------------------------------------------------------
  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # ----------------------------------------------------------------------------
  # Firewall Tags
  # ----------------------------------------------------------------------------
  tags = ["mate-allow-ssh", "mate-allow-nfs", "mate-allow-smb", "mate-allow-rdp"]
}


# ==============================================================================
# Data Source: Latest Ubuntu 26.04 LTS Image
# ------------------------------------------------------------------------------
# Retrieves the most recent Ubuntu 26.04 LTS image from ubuntu-os-cloud.
# Useful for validation or alternate boot scenarios.
# ==============================================================================

data "google_compute_image" "ubuntu_latest" {
  family  = "ubuntu-2604-lts-amd64"
  project = "ubuntu-os-cloud"
}