#!/bin/bash
# ==============================================================================
# startup_mate.sh  —  join the MATE desktop host to the mini-AD (SSSD)
#
# The image (02-packer) already has MATE, XRDP and the SSSD/realmd packages;
# this script does only the per-machine part. realmd joins the domain
# (computer object + keytab), and SSSD becomes the identity/auth provider over
# Kerberos. POSIX UIDs come from AD (ldap_id_mapping = False). The VM is
# private: users reach it through Guacamole over RDP (XRDP, a MATE desktop)
# or SSH, signed in with their AD password either way.
#
# GCP runs a startup script at every boot; the flag file makes this one run
# only once.
# ==============================================================================
FLAG_FILE=/root/.mate_provisioned
[ -f "$FLAG_FILE" ] && exit 0

set -euo pipefail
exec > >(tee -a /root/userdata.log | logger -t startup-script -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR
echo "mate startup start ($(date -Is))"

export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------------------
# Domain admin credential (used only to perform the join), read from Secret
# Manager with the VM's service-account token (metadata server; no gcloud).
# ------------------------------------------------------------------------------
MD="http://metadata.google.internal/computeMetadata/v1"
project=$(curl -fsS -H Metadata-Flavor:Google "$MD/project/project-id")
secret=""
for i in $(seq 1 30); do
  token=$(curl -fsS -H Metadata-Flavor:Google \
    "$MD/instance/service-accounts/default/token" | jq -r '.access_token // empty' || true)
  if [ -n "$token" ]; then
    secret=$(curl -fsS -H "Authorization: Bearer $token" \
      "https://secretmanager.googleapis.com/v1/projects/$project/secrets/${admin_secret}/versions/latest:access" \
      | jq -r '.payload.data // empty' | base64 -d || true)
  fi
  [ -n "$secret" ] && break
  echo "waiting for Secret Manager ($i/30)"
  sleep 10
done
[ -n "$secret" ]
admin_password=$(echo "$secret" | jq -r .password)
# The secret holds admin@<domain>; realm wants the bare account name.
admin_user=$(echo "$secret" | jq -r .username | sed 's/@.*//')

# ------------------------------------------------------------------------------
# Join with SSSD (realmd's default client software). The DC can still be
# settling when this VM boots, so retry the join a few times.
# ------------------------------------------------------------------------------
for i in $(seq 1 10); do
  if echo "$admin_password" | realm join -U "$admin_user" ${domain_fqdn} --verbose; then
    break
  fi
  [ "$i" -eq 10 ] && exit 1
  echo "realm join failed ($i/10); retrying"
  sleep 30
done

# ------------------------------------------------------------------------------
# SSSD tweaks:
#   - short login names (jsmith, not jsmith@domain)
#   - POSIX mapping: read uidNumber/gidNumber from AD
#   - home under /home/%u
# ------------------------------------------------------------------------------
sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/' /etc/sssd/sssd.conf
sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/'                     /etc/sssd/sssd.conf
sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|'         /etc/sssd/sssd.conf

# SSSD's AD provider enforces AD logon rights (GPO access control), choosing
# the right by PAM service name, and denies services it has no mapping for.
# sshd is mapped to "remote interactive" out of the box; XRDP's service is
# not, so desktop logins fail the account check ("User is not authorized")
# after a correct password. Map it like sshd.
sed -i '/^access_provider = ad/a ad_gpo_map_remote_interactive = +xrdp-sesman' /etc/sssd/sssd.conf

pam-auth-update --enable mkhomedir
sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs
systemctl restart sssd

# ------------------------------------------------------------------------------
# Passwordless sudo for the linux-admins domain group
# ------------------------------------------------------------------------------
echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10-linux-admins
chmod 440 /etc/sudoers.d/10-linux-admins

# ------------------------------------------------------------------------------
# SSH password logins — Guacamole's SSH connection passes the user's AD
# password through. Ubuntu's cloud image turns password auth off in
# 60-cloudimg-settings.conf; sshd takes the first value it reads, so a file
# that sorts earlier wins. Port 22 is open only to Guacamole (and IAP).
# ------------------------------------------------------------------------------
cat > /etc/ssh/sshd_config.d/10-guacamole-password-auth.conf <<'SSHD'
PasswordAuthentication yes
KbdInteractiveAuthentication yes
SSHD
systemctl restart ssh

# ------------------------------------------------------------------------------
# Sanity: resolve the demo users. Non-fatal.
# ------------------------------------------------------------------------------
for u in jsmith rpatel akumar edavis; do
  if id "$u" >/dev/null 2>&1; then echo "OK resolve: $u ($(id -u "$u"))"; else echo "WARN unresolved: $u"; fi
done

touch "$FLAG_FILE"
echo "mate startup done ($(date -Is))"
