# ==============================================================================
# Active Directory Naming Inputs
# ------------------------------------------------------------------------------
# Defines core domain identity variables for the Samba-based AD deployment.
# Includes DNS domain, Kerberos realm, and NetBIOS short name.
# ==============================================================================


# ==============================================================================
# DNS Zone / AD Domain (FQDN)
# ------------------------------------------------------------------------------
# Fully qualified domain name for the AD forest root domain.
# Used for DNS namespace and domain identity.
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
# Kerberos realm name, typically uppercase version of dns_zone.
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
# Pre-Windows 2000 short domain identifier.
# Typically <= 15 uppercase alphanumeric characters.
# Used by legacy SMB clients and some authentication flows.
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
# Distinguished Name container for new user objects.
# Must align with domain components derived from dns_zone.
# Example: CN=Users,DC=mcloud,DC=mikecloud,DC=com
# ==============================================================================

variable "user_base_dn" {
  description = "User base DN for LDAP (e.g., CN=Users,DC=mcloud,DC=mikecloud,DC=com)"
  type        = string
  default     = "CN=Users,DC=mcloud,DC=mikecloud,DC=com"
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