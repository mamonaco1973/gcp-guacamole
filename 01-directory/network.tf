# ==============================================================================
# Custom VPC, Subnet, Router, and NAT for AD Environment
# ------------------------------------------------------------------------------
# Provisions:
#   1. Custom-mode VPC (no automatic subnets).
#   2. Dedicated subnet for AD resources.
#   3. Cloud Router for routing and NAT support.
#   4. Cloud NAT for outbound internet without public IPs.
#
# Design Notes:
#   - Custom VPC prevents implicit subnet creation.
#   - Subnet defined in us-central1 with CIDR 10.1.0.0/24.
#   - Router is required for Cloud NAT operation.
#   - NAT enables secure egress for private instances.
# ==============================================================================


# ==============================================================================
# VPC Network: Active Directory VPC
# ------------------------------------------------------------------------------
# Creates a custom VPC.
# auto_create_subnetworks=false enforces explicit subnet control.
# ==============================================================================

resource "google_compute_network" "ad_vpc" {
  name                    = var.vpc
  auto_create_subnetworks = false
}


# ==============================================================================
# Subnet: Active Directory Subnet
# ------------------------------------------------------------------------------
# Defines the AD subnet inside the VPC.
# Region: us-central1.
# CIDR: 10.1.0.0/24 (must not overlap with other networks).
# ==============================================================================

resource "google_compute_subnetwork" "ad_subnet" {
  name          = var.subnet
  region        = "us-central1"
  network       = google_compute_network.ad_vpc.id
  ip_cidr_range = "10.1.0.0/24"
}


# ==============================================================================
# Cloud Router
# ------------------------------------------------------------------------------
# Required for Cloud NAT.
# Supports dynamic routing and BGP if extended in future.
# ==============================================================================

resource "google_compute_router" "ad_router" {
  name    = "mate-ad-router"
  network = google_compute_network.ad_vpc.id
  region  = "us-central1"
}


# ==============================================================================
# Cloud NAT
# ------------------------------------------------------------------------------
# Provides outbound internet access for private subnet resources.
# No public IPs required on instances.
# NAT IPs allocated automatically.
# Flow logging enabled with filter set to ALL.
# ==============================================================================

resource "google_compute_router_nat" "ad_nat" {
  name   = "mate-ad-nat"
  router = google_compute_router.ad_router.name
  region = google_compute_router.ad_router.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ALL"
  }
}