#!/usr/bin/env bash
# enable_plasma_x11.sh — Make Plasma (X11) available & force SDDM to use X11
# Safe, idempotent, with checks and clear logging.

set -euo pipefail

log() { printf "[plasma-x11] %s\n" "$*"; }
die() { printf "[plasma-x11][ERROR] %s\n" "$*" >&2; exit 1; }
need() { for c in "$@"; do command -v "$c" >/dev/null 2>&1 || die "Missing command: $c"; done; }

main() {
  # 0) Root check + basic tools
  [ "${EUID:-$(id -u)}" -eq 0 ] || die "Run as root (sudo)."
  need pacman systemctl tee sed grep

  # 1) Package installs (idempotent)
  log "Ensuring packages are present: plasma-x11-session, xorg-server, sddm"
  pacman -Sy --needed --noconfirm plasma-x11-session xorg-server sddm

  # 2) Verify the X11 session .desktop exists
  if [ ! -f /usr/share/xsessions/plasmax11.desktop ] && [ ! -f /usr/share/xsessions/plasma.desktop ]; then
    die "Plasma X11 session file not found after install. Check pacman output and mirrors."
  fi

  # 3) Force SDDM to use X11 (greeter on Xorg; helps NVIDIA and exposes X11 entry reliably)
  install -d -m 0755 /etc/sddm.conf.d
  CONF=/etc/sddm.conf.d/10-displayserver.conf
  if [ -f "$CONF" ] && grep -q '^DisplayServer=wayland' "$CONF"; then
    log "Overriding existing wayland setting with X11 in $CONF"
  fi
  cat > "$CONF" <<'EOF'
[General]
DisplayServer=x11
EOF
  log "Wrote $CONF (DisplayServer=x11)."

  # 4) Make sure the system boots to the greeter and SDDM is enabled
  systemctl set-default graphical.target >/dev/null
  systemctl enable sddm >/dev/null
  log "Set default target to graphical and enabled sddm."

  # 5) Show what sessions SDDM can see
  log "Available X11 sessions:"
  ls -1 /usr/share/xsessions || true
  log "Available Wayland sessions:"
  ls -1 /usr/share/wayland-sessions || true

  # 6) Final reminder before bouncing SDDM
  if systemctl is-active --quiet sddm; then
    log "Restarting SDDM now (this will close any active graphical session)."
    systemctl restart sddm
  else
    log "SDDM is not active; starting it."
    systemctl start sddm
  fi

  log "Done. At the login screen, open the session menu and choose 'Plasma (X11)'."
}

main "$@"
