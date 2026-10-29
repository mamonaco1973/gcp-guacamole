#!/bin/bash
set -euo pipefail

# ==========================================================================================
# This script prepares an Ubuntu host for:
#   - Active Directory domain joins using realmd, SSSD, and adcli
#   - NSS/PAM integration for domain users and automatic home directory creation
#   - Samba utilities required for Kerberos, NTLM, and domain discovery
# ==========================================================================================

export DEBIAN_FRONTEND=noninteractive

# Snap stays installed: Firefox is a snap on 26.04, and the XAUTHORITY
# export in /etc/xrdp/startwm.sh (xrdp.sh) lets snaps open windows under XRDP.
# GCP images ship gcloud as a snap; gcloudcli.sh installs the apt package
# instead, so remove the snap once seeding has finished.
sudo snap wait system seed.loaded
sudo snap remove --purge google-cloud-cli

sudo apt-get update -y

# ------------------------------------------------------------------------------------------
# Install Core AD, NSS, Samba, Kerberos, NFS, and Utility Packages
# ------------------------------------------------------------------------------------------
# Includes:
#   - realmd / adcli / krb5-user     : Domain discovery and Kerberos auth
#   - sssd-ad / libnss-sss / libpam-sss : Identity + authentication via SSSD
#   - samba-common-bin / samba-libs  : Required for domain membership operations
#   - oddjob / oddjob-mkhomedir      : Auto-create home directories for AD users
#   - nfs-common                     : Required for EFS and NFS mounts
#   - stunnel4                       : Enables TLS for amazon-efs-utils
#   - less / unzip / nano / vim      : Basic utilities
# ------------------------------------------------------------------------------------------

apt-get install -y less unzip realmd sssd-ad sssd-tools libnss-sss \
    libpam-sss adcli samba samba-common-bin samba-libs oddjob \
    oddjob-mkhomedir packagekit krb5-user nano vim nfs-common \
    winbind libpam-winbind libnss-winbind stunnel4 jq

