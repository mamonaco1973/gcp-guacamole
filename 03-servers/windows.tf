# ==============================================================================
# SysAdmin Credentials + Windows AD Management VM
# ------------------------------------------------------------------------------
# Provisions:
#   1. Random SysAdmin password stored in GCP Secret Manager.
#   2. Windows Server 2022 VM, private, joined to the mini-AD at first boot.
#   3. Data source resolving the latest Windows Server 2022 image.
#
# Notes:
#   - No public IP. Guacamole reaches it on 3389 (01-directory/firewall.tf);
#     users sign in through Guacamole as MCLOUD\<user>.
#   - The startup PowerShell script joins the domain and reboots once.
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
  secret_id = "sysadmin-ad-credentials-guacamole"

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
# Windows AD Management VM
# ------------------------------------------------------------------------------
# Windows Server 2022 with the AD admin tools, joined to the domain by its
# startup script. mcloud-users members may sign in over RDP.
# ==============================================================================

resource "google_compute_instance" "windows" {
  name         = "win-ad-${random_string.vm_suffix.result}"
  machine_type = "e2-standard-2"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.windows_2022.self_link
    }
  }

  # No access_config block: no public IP. Outbound goes through Cloud NAT.
  network_interface {
    network    = var.vpc
    subnetwork = var.subnet
  }

  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    windows-startup-script-ps1 = templatefile("./scripts/ad_join.ps1", {
      domain_fqdn  = var.dns_zone
      netbios      = var.netbios
      admin_secret = "admin-ad-credentials-guacamole"
    })
    admin_username = "sysadmin"
    admin_password = random_password.sysadmin_password.result
  }

  # 01-directory/firewall.tf: Guacamole → 3389.
  tags = ["windows"]
}


# ==============================================================================
# Data Source: Windows Server 2022 Image
# ------------------------------------------------------------------------------
# Resolves the latest image in the windows-2022 family from windows-cloud.
# ==============================================================================

data "google_compute_image" "windows_2022" {
  family  = "windows-2022"
  project = "windows-cloud"
}
