# ==============================================================================
# FILE: guacamole.tf
# ------------------------------------------------------------------------------
# The Apache Guacamole server: private, behind the load balancer
# (loadbalancer.tf). It signs users in against the mini-AD and opens RDP to
# the Windows host, and RDP (XRDP) and SSH to the MATE host, on their behalf.
# Setup is in scripts/startup_guacamole.sh.
# ==============================================================================

resource "google_compute_instance" "guacamole" {
  name         = "guacamole-${random_string.vm_suffix.result}"
  machine_type = "e2-medium" # guacd + Tomcat + PostgreSQL
  zone         = var.zone

  # Canonical Ubuntu 24.04 (not the Packer image): it only runs Docker.
  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu_2404.self_link
      size  = 30 # three container images plus PostgreSQL
    }
  }

  # No access_config block: no public IP. The load balancer reaches it on
  # 8080; outbound (Docker Hub, apt) goes through Cloud NAT.
  network_interface {
    network    = var.vpc
    subnetwork = var.subnet
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  # Replaces the VM when the script (or a value in it) changes, so the server
  # is rebuilt instead of left running with a stale configuration.
  metadata_startup_script = templatefile("./scripts/startup_guacamole.sh", {
    admin_secret = "admin-ad-credentials-guacamole"
    guac_version = "1.6.0"
    dc_fqdn      = local.dc_fqdn
    base_dn      = local.base_dn
    netbios      = var.netbios
    windows_ip   = google_compute_instance.windows.network_interface[0].network_ip
    mate_ip      = google_compute_instance.mate.network_interface[0].network_ip
  })

  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # 01-directory/firewall.tf: load balancer → 8080; IAP → 22; and the
  # source tag that lets it reach the Windows and MATE hosts.
  tags = ["guacamole"]
}

data "google_compute_image" "ubuntu_2404" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}
