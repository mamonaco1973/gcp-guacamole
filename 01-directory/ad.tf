# ==============================================================================
# Mini Active Directory (mini-ad) Module Invocation
# ------------------------------------------------------------------------------
# Purpose:
#   - Invokes the reusable "mini-ad" module to provision an Ubuntu AD DC.
#   - Passes networking, DNS, and authentication inputs to the module.
#   - Supplies user account definitions via a rendered JSON template blob.
# ==============================================================================

module "mini_ad" {
  source            = "github.com/mamonaco1973/module-gcp-mini-ad" # Path to the mini-ad Terraform module
  netbios           = var.netbios                                  # NetBIOS domain name (e.g., MCLOUD)
  network           = google_compute_network.ad_vpc.id             # VPC where the AD will reside
  realm             = var.realm                                    # Kerberos realm (usually UPPERCASE DNS domain)
  users_json        = local.users_json                             # JSON blob of users and passwords (built below)
  user_base_dn      = var.user_base_dn                             # Base DN for user accounts in LDAP
  ad_admin_password = local.passwords["admin"]                     # Randomized AD administrator password
  dns_zone          = var.dns_zone                                 # DNS zone (e.g., mcloud.mikecloud.com)
  subnetwork        = google_compute_subnetwork.ad_subnet.id       # Subnet for AD VM placement
  email             = local.service_account_email                  # Service account email
  machine_type      = var.machine_type                             # Machine type for AD VM

  # Ensure NAT + router resources exist before AD bootstrap runs.
  # This supports outbound package installs and update operations.
  depends_on = [google_compute_subnetwork.ad_subnet,
    google_compute_router.ad_router,
  google_compute_router_nat.ad_nat]
}

# ==============================================================================
# Local Variable: users_json
# ------------------------------------------------------------------------------
# Renders ./scripts/users.json.template into a single JSON blob used by mini-ad.
# The template is populated with domain metadata and per-user random passwords.
# The mini-ad bootstrap consumes this to create demo/test users automatically.
# ==============================================================================

locals {
  users_json = templatefile("./scripts/users.json.template", {
    USER_BASE_DN    = var.user_base_dn            # Base DN for placing new users in LDAP
    DNS_ZONE        = var.dns_zone                # AD-integrated DNS zone
    REALM           = var.realm                   # Kerberos realm (FQDN in uppercase)
    NETBIOS         = var.netbios                 # NetBIOS domain name
    jsmith_password = local.passwords["jsmith"]  # Random password for John Smith
    edavis_password = local.passwords["edavis"]  # Random password for Emily Davis
    rpatel_password = local.passwords["rpatel"]  # Random password for Raj Patel
    akumar_password = local.passwords["akumar"]  # Random password for Amit Kumar
  })
}