# ==============================================================================
# Firewall Rules: who may reach which server
# ------------------------------------------------------------------------------
#   internet ─443/80─▶ Load Balancer ─8080─▶ Guacamole ─3389──────▶ Windows
#                                                      └─22, 3389─▶ MATE
#
# Design Notes:
#   - No server has a public IP. The load balancer (03-servers) is the only
#     way in; Cloud NAT is outbound only.
#   - A custom VPC denies all ingress by default, so these rules are the
#     complete list. Servers carry the target tags in 03-servers.
#   - The mini-AD module opens the AD ports on the DC itself.
#   - IAP TCP forwarding (35.235.240.0/20) is the break-glass admin path:
#     gcloud compute ssh --tunnel-through-iap, for logs and troubleshooting.
# ==============================================================================


# ==============================================================================
# Load Balancer → Guacamole (8080)
# ------------------------------------------------------------------------------
# Google Front Ends and health checkers for the global external Application
# Load Balancer connect from these two ranges.
# ==============================================================================

resource "google_compute_firewall" "lb_to_guacamole" {
  name    = "guacamole-allow-lb"
  network = google_compute_network.ad_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["guacamole"]
}


# ==============================================================================
# Guacamole → Windows (RDP)
# ==============================================================================

resource "google_compute_firewall" "guacamole_to_windows" {
  name    = "guacamole-allow-windows-rdp"
  network = google_compute_network.ad_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_tags = ["guacamole"]
  target_tags = ["windows"]
}


# ==============================================================================
# Guacamole → MATE (SSH and RDP)
# ==============================================================================

resource "google_compute_firewall" "guacamole_to_mate" {
  name    = "guacamole-allow-mate"
  network = google_compute_network.ad_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  source_tags = ["guacamole"]
  target_tags = ["mate"]
}


# ==============================================================================
# IAP → Linux servers (SSH, break-glass admin access)
# ==============================================================================

resource "google_compute_firewall" "iap_ssh" {
  name    = "guacamole-allow-iap-ssh"
  network = google_compute_network.ad_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["guacamole", "mate"]
}
