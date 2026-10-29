#!/bin/bash
set -euo pipefail

# ================================================================================
# Ubuntu MATE core: the MATE desktop, Firefox (snap), cloud clean-up
# ================================================================================
#
# ubuntu-mate-core is the Ubuntu MATE desktop and its look without the full
# application set (no office suite, mail or media apps), sized for XRDP
# sessions reached through Guacamole.
#
# ================================================================================

export DEBIAN_FRONTEND=noninteractive

# --------------------------------------------------------------------------------
# MATE desktop, terminal, file manager (Caja), text editor (Pluma)
# --------------------------------------------------------------------------------
echo "NOTE: [desktop] installing Ubuntu MATE core"
apt-get update -y
apt-install-retry -y ubuntu-mate-core mate-terminal pluma xdg-utils xsel xclip

update-alternatives --set x-terminal-emulator /usr/bin/mate-terminal.wrapper \
  2>/dev/null || true

# --------------------------------------------------------------------------------
# Firefox from the Snap Store, Ubuntu's default packaging. Snaps need the
# XAUTHORITY export in /etc/xrdp/startwm.sh (03-xrdp.sh) to open windows in an
# XRDP session.
# --------------------------------------------------------------------------------
echo "NOTE: [desktop] installing firefox (snap)"
snap wait system seed.loaded
snap install firefox

# A snap registers no Debian alternatives, so anything that calls
# x-www-browser / www-browser finds nothing. Register Firefox for both names.
#
# Through a wrapper, not a symlink: /snap/bin/firefox is itself a symlink to
# /usr/bin/snap, which picks the app from the name it is invoked by -- run as
# "www-browser" it does not know it means Firefox.
cat > /usr/local/bin/firefox-snap <<'WRAPPER'
#!/bin/sh
exec /snap/bin/firefox "$@"
WRAPPER
chmod 755 /usr/local/bin/firefox-snap
for name in x-www-browser www-browser; do
  update-alternatives --install "/usr/bin/$name" "$name" \
    /usr/local/bin/firefox-snap 200
done

# MATE (and xdg-open) resolve the browser from the XDG MIME defaults.
# System-wide defaults live in /etc/xdg/mimeapps.list; the .desktop file is the
# one snapd generates.
FIREFOX_DESKTOP=/var/lib/snapd/desktop/applications/firefox_firefox.desktop
test -f "$FIREFOX_DESKTOP"
tee /etc/xdg/mimeapps.list >/dev/null <<'MIME'
[Default Applications]
x-scheme-handler/http=firefox_firefox.desktop
x-scheme-handler/https=firefox_firefox.desktop
text/html=firefox_firefox.desktop
application/xhtml+xml=firefox_firefox.desktop
MIME

# --------------------------------------------------------------------------------
# Desktop icons for every new user. A symlink (not a copy) keeps the launcher
# trusted, so MATE doesn't ask before running it.
# --------------------------------------------------------------------------------
echo "NOTE: [desktop] desktop icons for new users"
mkdir -p /etc/skel/Desktop
ln -sf "$FIREFOX_DESKTOP" /etc/skel/Desktop/firefox_firefox.desktop
ln -sf /usr/share/applications/mate-terminal.desktop /etc/skel/Desktop/mate-terminal.desktop

# --------------------------------------------------------------------------------
# Things a headless cloud desktop never uses, which pop up prompts or errors
# inside an XRDP session: power management, crash reporting, update prompts.
# Disabled rather than purged: removing them would take the ubuntu-mate-core
# metapackage with them.
# --------------------------------------------------------------------------------
echo "NOTE: [desktop] disabling cloud-irrelevant services"
rm -f /etc/xdg/autostart/mate-power-manager.desktop \
      /etc/xdg/autostart/update-notifier.desktop
sed -i 's/enabled=1/enabled=0/' /etc/default/apport 2>/dev/null || true
for unit in apport.service bluetooth.service cups.service cups-browsed.service \
            ModemManager.service; do
  systemctl disable "$unit" 2>/dev/null || true
done

# --------------------------------------------------------------------------------
# NetworkManager: the desktop can pull it in, and it fights cloud-init and
# systemd-networkd for the NIC, so the VM can lose its network after a reboot.
# Remove it, pin it out, and mask its units.
# --------------------------------------------------------------------------------
echo "NOTE: [desktop] removing NetworkManager"
apt-get purge -y network-manager 2>/dev/null || true
tee /etc/apt/preferences.d/disable-network-manager >/dev/null <<'EOF'
Package: network-manager
Pin: release *
Pin-Priority: -1

Package: network-manager-*
Pin: release *
Pin-Priority: -1
EOF
systemctl mask NetworkManager.service NetworkManager-wait-online.service \
  2>/dev/null || true

# A display manager on the console is pointless here (XRDP starts its own X
# sessions) and only competes for resources.
for dm in lightdm sddm gdm3; do
  systemctl disable "$dm" 2>/dev/null || true
done
systemctl set-default multi-user.target

echo "NOTE: [desktop] done"
