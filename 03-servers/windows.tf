# ==============================================================================
# SysAdmin Credentials + Windows AD Management VM + RDP Firewall
# ------------------------------------------------------------------------------
# Provisions:
#   1. Random SysAdmin password stored in GCP Secret Manager.
#   2. Firewall rule allowing inbound RDP (TCP/3389) to tagged instances.
#   3. Windows Server 2022 VM for AD administration and domain join tasks.
#   4. Data source resolving the latest Windows Server 2022 image.
#
# Notes:
#   - Firewall rules are tag-based in GCP (instances must have target_tags).
#   - RDP is open to 0.0.0.0/0 for lab use (restrict in production).
#   - Windows VM uses a startup PowerShell script for domain join automation.
# ==============================================================================


# ==============================================================================
# SysAdmin Credentials
# ------------------------------------------------------------------------------
# Generates a strong random password and stores the credential JSON in
# Secret Manager for operator retrieval and automation workflows.
# ==============================================================================

resource "random_password" "sysadmin_password" {
  length           = 24
  special          = true
  override_special = "-_."
}

resource "google_secret_manager_secret" "sysadmin_secret" {
  secret_id = "sysadmin-ad-credentials-mate"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "admin_secret_version" {
  secret = google_secret_manager_secret.sysadmin_secret.id
  secret_data = jsonencode({
    username = "sysadmin"
    password = random_password.sysadmin_password.result
  })
}


# ==============================================================================
# Firewall Rule: Allow RDP
# ------------------------------------------------------------------------------
# Allows inbound TCP/3389 to instances tagged with "allow-rdp".
# Source range is open for lab use (restrict to trusted IPs in production).
# ==============================================================================

resource "google_compute_firewall" "allow_rdp" {
  name    = "mate-allow-rdp"
  network = var.vpc

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  target_tags   = ["mate-allow-rdp"]
  source_ranges = ["0.0.0.0/0"]
}


# ==============================================================================
# Windows AD Management VM
# ------------------------------------------------------------------------------
# Deploys a Windows Server 2022 instance for AD administration.
# Instance is reachable via RDP and executes a startup script to join AD.
# SysAdmin credentials are passed via instance metadata for the join process.
# ==============================================================================

resource "google_compute_instance" "windows_ad_instance" {
  name         = "win-ad-${random_string.vm_suffix.result}"
  machine_type = "e2-standard-2"
  zone         = "us-central1-a"

  # ----------------------------------------------------------------------------
  # Boot Disk
  # ----------------------------------------------------------------------------
  boot_disk {
    initialize_params {
      image = data.google_compute_image.windows_2022.self_link
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
  # Service Account
  # ----------------------------------------------------------------------------
  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # ----------------------------------------------------------------------------
  # Metadata (Startup Script + Admin Credential Inputs)
  # ----------------------------------------------------------------------------
  metadata = {
    windows-startup-script-ps1 = templatefile("./scripts/ad_join.ps1", {
      domain_fqdn = "mcloud.mikecloud.com"
      nfs_gateway = google_compute_instance.desktop_instance.network_interface[0].network_ip
    })

    admin_username = "sysadmin"
    admin_password = random_password.sysadmin_password.result
  }

  # ----------------------------------------------------------------------------
  # Firewall Tags
  # ----------------------------------------------------------------------------
  tags = ["mate-allow-rdp"]
}


# ==============================================================================
# Data Source: Latest Windows Server 2022 Image
# ------------------------------------------------------------------------------
# Resolves the most recent Windows Server 2022 image from windows-cloud.
# Ensures new deployments use a patched base OS image.
# ==============================================================================

data "google_compute_image" "windows_2022" {
  family  = "windows-2022"
  project = "windows-cloud"
}