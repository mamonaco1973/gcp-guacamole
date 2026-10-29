# ==============================================================================
# Active Directory User Credentials in GCP Secret Manager
# ==============================================================================
# Provisions:
#   1. Memorable passwords per AD user: <word>-<6digit>
#   2. Secret Manager secrets to store credentials as JSON.
#   3. IAM bindings so a service account can read these secrets.
#
# Notes:
#   - Password format: "<memorable_word>-<6digit>" (one word + one number).
#   - Secret payload: {"username":"<user>@<dns_zone>","password":"<generated>"}.
#   - Access is granted via roles/secretmanager.secretAccessor per secret.
# ==============================================================================

# ==============================================================================
# Memorable Word List
# ==============================================================================
# Word pool used by random_shuffle to create human-friendly passwords.
# Each user gets exactly one word, selected independently per user.
# ==============================================================================
locals {
  memorable_words = [
    "bright",
    "simple",
    "orange",
    "window",
    "little",
    "people",
    "friend",
    "yellow",
    "animal",
    "family",
    "circle",
    "moment",
    "summer",
    "button",
    "planet",
    "rocket",
    "silver",
    "forest",
    "stream",
    "butter",
    "castle",
    "wonder",
    "gentle",
    "driver",
    "coffee"
  ]
}

# ==============================================================================
# User Accounts to Generate
# ==============================================================================
# Map of AD usernames (key) to friendly display names (value).
# Keys are used for resource for_each, secret naming, and UPN construction.
# ==============================================================================
locals {
  ad_users = {
    admin  = "Admin"
    jsmith = "John Smith"
    edavis = "Emily Davis"
    rpatel = "Raj Patel"
    akumar = "Amit Kumar"
  }
}

# ==============================================================================
# Random Word (one per user)
# ==============================================================================
# Picks a single word per user from local.memorable_words.
# random_shuffle is used so the selected word is stable per state lifecycle.
# ==============================================================================
resource "random_shuffle" "word" {
  for_each     = local.ad_users
  input        = local.memorable_words
  result_count = 1
}

# ==============================================================================
# Random 6-digit number (one per user)
# ==============================================================================
# Generates a per-user 6-digit integer used as the numeric suffix.
# ==============================================================================
resource "random_integer" "num" {
  for_each = local.ad_users
  min      = 100000
  max      = 999999
}

# ==============================================================================
# Build the Password: <word>-<number>
# ==============================================================================
# Constructs the final password per user using the selected word and number.
# Example: "orange-123456"
# ==============================================================================
locals {
  passwords = {
    for user, fullname in local.ad_users :
    user => "${random_shuffle.word[user].result[0]}-${random_integer.num[user].result}"
  }
}

# ==============================================================================
# Create Secret + Version for Each User
# ==============================================================================
# Secret resource creates the container (metadata + replication policy).
# Secret version writes the current credential JSON payload to the secret.
# ==============================================================================
resource "google_secret_manager_secret" "ad_secret" {
  for_each  = local.ad_users
  secret_id = "${each.key}-ad-credentials-mate"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "ad_secret_version" {
  for_each = local.ad_users
  secret  = google_secret_manager_secret.ad_secret[each.key].id

  secret_data = jsonencode({
    username = "${each.key}@${var.dns_zone}"
    password = local.passwords[each.key]
  })
}

# ==============================================================================
# Locals: Secret List
# ==============================================================================
# Builds a list of secret_id strings for IAM binding iteration.
# Uses secret_id (not full resource ID) because IAM binding uses secret_id.
# ==============================================================================
locals {
  secrets = [
    for user, fullname in local.ad_users :
    google_secret_manager_secret.ad_secret[user].secret_id
  ]
}

# ==============================================================================
# IAM Binding: Grant Secret Access
# ==============================================================================
# Grants the service account read access to each secret.
# local.service_account_email must be defined elsewhere in the module.
# ==============================================================================
resource "google_secret_manager_secret_iam_binding" "secret_access" {
  for_each  = toset(local.secrets)
  secret_id = each.key
  role      = "roles/secretmanager.secretAccessor"

  members = [
    "serviceAccount:${local.service_account_email}"
  ]
}