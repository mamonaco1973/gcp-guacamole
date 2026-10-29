# ==============================================================================
# Google Cloud Filestore (Basic NFS Server) + Firewall Rule
# ------------------------------------------------------------------------------
# Provisions:
#   1. Zonal Filestore instance for managed NFS storage.
#   2. File share with export options for client access control.
#   3. Firewall rule permitting NFS traffic (TCP/UDP 2049).
#
# Design Notes:
#   - Basic tiers (HDD/SSD) support NFSv3 only.
#   - Minimum capacity for Basic tier is 1024 GiB (1 TB).
#   - Filestore is deployed in a specific zone, not region-wide.
#   - Access is open to 0.0.0.0/0 for lab use (restrict in production).
# ==============================================================================

resource "google_filestore_instance" "nfs_server" {

  # ----------------------------------------------------------------------------
  # Filestore Configuration
  # ----------------------------------------------------------------------------
  # Name must be unique within the project.
  # Tier controls performance and protocol support.
  # Location must be a zone (e.g., us-central1-b).
  # Project ID sourced from decoded credentials.
  name     = "mate-nfs-server"
  tier     = "BASIC_HDD"
  location = "us-central1-b"
  project  = local.credentials.project_id

  # ----------------------------------------------------------------------------
  # File Share Configuration
  # ----------------------------------------------------------------------------
  # capacity_gb minimum for Basic tier is 1024 GiB.
  # nfs_export_options define client access behavior.
  file_shares {
    capacity_gb = 1024
    name        = "filestore"

    nfs_export_options {
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
      ip_ranges   = ["0.0.0.0/0"]
    }
  }

  # ----------------------------------------------------------------------------
  # Network Configuration
  # ----------------------------------------------------------------------------
  # Attaches Filestore to existing VPC.
  # MODE_IPV4 is standard for most lab deployments.
  networks {
    network = data.google_compute_network.ad_vpc.name
    modes   = ["MODE_IPV4"]
  }
}

# ==============================================================================
# Firewall Rule: Allow NFS Traffic
# ------------------------------------------------------------------------------
# Permits inbound TCP and UDP traffic on port 2049.
# Required for Linux clients mounting Filestore over NFS.
# Source range is open for lab use (restrict in production).
# ==============================================================================

resource "google_compute_firewall" "allow_nfs" {
  name    = "mate-allow-nfs"
  network = data.google_compute_network.ad_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["2049"]
  }

  allow {
    protocol = "udp"
    ports    = ["2049"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# ==============================================================================
# Output: Filestore IP Address (Optional)
# ------------------------------------------------------------------------------
# Example mount syntax:
#   <FILSTORE_IP>:/filestore
# Uncomment if direct Terraform output is required.
# ==============================================================================

# output "filestore_ip" {
#   value = google_filestore_instance.nfs_server.networks[0].ip_addresses[0]
# }