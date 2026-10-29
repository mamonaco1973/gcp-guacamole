# ==============================================================================
# Active Directory Naming and Infrastructure Inputs
# ------------------------------------------------------------------------------
# Defines domain naming, LDAP, compute, and networking parameters for the
# mini Active Directory deployment on Google Cloud.
#
# Categories:
#   - Domain identity (DNS, Kerberos, NetBIOS).
#   - LDAP placement (user base DN).
#   - Compute sizing and location.
#   - Network resource naming.
# ==============================================================================


# ==============================================================================
# DNS Zone / AD Domain (FQDN)
# ------------------------------------------------------------------------------
# Fully qualified domain name for the AD forest root domain.
# Used by Samba AD DC for DNS namespace and domain identity.
# Example: mcloud.mikecloud.com
# ==============================================================================

variable "dns_zone" {
  description = "AD DNS zone / domain (e.g., mcloud.mikecloud.com)"
  type        = string
  default     = "mcloud.mikecloud.com"
}


# ==============================================================================
# Kerberos Realm (UPPERCASE)
# ------------------------------------------------------------------------------
# Kerberos realm name, typically the uppercase version of dns_zone.
# Required for proper Kerberos authentication configuration.
# Example: MCLOUD.MIKECLOUD.COM
# ==============================================================================

variable "realm" {
  description = "Kerberos realm (usually DNS zone in UPPERCASE, e.g., MCLOUD.MIKECLOUD.COM)"
  type        = string
  default     = "MCLOUD.MIKECLOUD.COM"
}


# ==============================================================================
# NetBIOS Short Domain Name
# ------------------------------------------------------------------------------
# Pre-Windows 2000 short domain name.
# Typically <= 15 uppercase alphanumeric characters.
# Used by legacy clients and certain SMB authentication flows.
# Example: MCLOUD
# ==============================================================================

variable "netbios" {
  description = "NetBIOS short domain name (e.g., MCLOUD)"
  type        = string
  default     = "MCLOUD"
}


# ==============================================================================
# User Base DN for LDAP
# ------------------------------------------------------------------------------
# Distinguished Name container where new user objects are created.
# Must align with the domain components derived from dns_zone.
# Example: CN=Users,DC=mcloud,DC=mikecloud,DC=com
# ==============================================================================

variable "user_base_dn" {
  description = "User base DN for LDAP (e.g., CN=Users,DC=mcloud,DC=mikecloud,DC=com)"
  type        = string
  default     = "CN=Users,DC=mcloud,DC=mikecloud,DC=com"
}


# ==============================================================================
# Deployment Zone
# ------------------------------------------------------------------------------
# Google Cloud zone where the mini AD instance will be created.
# Example: us-central1-a
# ==============================================================================

variable "zone" {
  description = "GCP zone for deployment (e.g., us-central1-a)"
  type        = string
  default     = "us-central1-a"
}


# ==============================================================================
# Machine Type for mini AD Instance
# ------------------------------------------------------------------------------
# Determines compute resources allocated to the AD VM.
# Minimum recommended size is e2-small.
# ==============================================================================

variable "machine_type" {
  description = "Machine type for mini AD instance (minimum is e2-small)"
  type        = string
  default     = "e2-medium"
}


# ==============================================================================
# VPC Name for mini AD Instance
# ------------------------------------------------------------------------------
# Name of the VPC network where the AD instance will reside.
# ==============================================================================

variable "vpc" {
  description = "Network for mini AD instance (e.g., ad-vpc)"
  type        = string
  default     = "mate-vpc"
}


# ==============================================================================
# Subnet Name for mini AD Instance
# ------------------------------------------------------------------------------
# Name of the subnet within the VPC used for AD placement.
# ==============================================================================

variable "subnet" {
  description = "Sub-network for mini AD instance (e.g., ad-subnet)"
  type        = string
  default     = "mate-subnet"
}