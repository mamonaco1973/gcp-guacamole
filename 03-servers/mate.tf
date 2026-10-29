# ==============================================================================
# FILE: mate.tf
# ------------------------------------------------------------------------------
# The MATE desktop host: Ubuntu 26.04 with MATE and XRDP, from the Packer
# image (02-packer). Private (no public IP); Guacamole reaches it on 22 and
# 3389. The startup script joins it to the mini-AD with SSSD, so AD users sign
# in with their own password and get a home directory on first login.
# ==============================================================================

resource "google_compute_instance" "mate" {
  name         = "mate-${random_string.vm_suffix.result}"
  machine_type = "e2-standard-2" # a desktop session per user
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.mate_packer_image.self_link
    }
  }

  # No access_config block: no public IP. Outbound goes through Cloud NAT.
  network_interface {
    network    = var.vpc
    subnetwork = var.subnet
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  # metadata_startup_script (unlike a "startup-script" metadata key) replaces
  # the VM when the script changes, so the host is rebuilt instead of left
  # running with a stale configuration. GCP runs it at every boot; the script
  # exits early once it has finished the first time.
  metadata_startup_script = templatefile("./scripts/startup_mate.sh", {
    domain_fqdn  = var.dns_zone
    admin_secret = "admin-ad-credentials-guacamole"
  })

  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # 01-directory/firewall.tf: Guacamole → 22, 3389; IAP → 22.
  tags = ["mate"]
}
