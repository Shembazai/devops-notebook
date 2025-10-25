#!/usr/bin/env bash
# use_konsole.sh — Revert to Konsole as the default terminal and remove Kitty.
# - Ensures Konsole is installed
# - Removes /usr/local/bin/konsole shim (if we created one earlier)
# - Sets Konsole as KDE default terminal
# - Binds Ctrl+Alt+T to launch Konsole
# - Removes kitty (optional, controlled below)
# Idempotent & chatty.

set -euo pipefail

WANT_REMOVE_KITTY=1   # set to 0 if you want to keep kitty installed

log(){ printf "[konsole-revert] %s\n" "$*"; }
die(){ printf "[konsole-revert][ERROR] %s\n" "$*" >&2; exit 1; }

need(){ for c in "$@"; do command -v "$c" >/dev/null 2>&1 || die "Missing command: $c"; done; }

main() {
  need kwriteconfig6 kbuildsycoca6

  # --- Ensure Konsole is installed ---
  log "Ensuring Konsole is installed..."
  if ! command -v konsole >/dev/null 2>&1; then
    need sudo pacman
    sudo pacman -S --needed --noconfirm konsole
  fi

  # --- Remove shim /usr/local/bin/konsole if it redirects to kitty ---
  if [ -x /usr/local/bin/konsole ]; then
    if grep -qi 'kitty' /usr/local/bin/konsole 2>/dev/null; then
      log "Removing shim /usr/local/bin/konsole (was redirecting to kitty)..."
      sudo rm -f /usr/local/bin/konsole
    else
      log "/usr/local/bin/konsole exists and does not mention kitty; leaving it alone."
    fi
  fi

  # --- Make Konsole KDE's default terminal ---
  log "Setting Konsole as KDE default terminal..."
  kwriteconfig6 --file kdeglobals --group General --key TerminalApplication konsole

  # --- Bind Ctrl+Alt+T to Konsole ---
  # This writes to ~/.config/kglobalshortcutsrc in the group org.kde.konsole.desktop
  # Value format: "PrimaryShortcut,AlternateShortcut,Description"
  log "Binding Ctrl+Alt+T to launch Konsole..."
  kwriteconfig6 --file kglobalshortcutsrc --group org.kde.konsole.desktop --key _launch "Ctrl+Alt+T,none,Open Terminal"

  # If Konsole desktop ID differs, also write the fallback group used on some installs
  kwriteconfig6 --file kglobalshortcutsrc --group "org.kde.konsole" --key _launch "Ctrl+Alt+T,none,Open Terminal" || true

  # --- Rebuild KDE service cache ---
  log "Rebuilding KDE service cache..."
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

  # --- Restart global accelerator to load new shortcuts (best-effort; otherwise relog) ---
  if command -v kquitapp6 >/dev/null 2>&1; then
    log "Restarting kglobalaccel..."
    kquitapp6 kglobalaccel >/dev/null 2>&1 || true
    if command -v kglobalaccel6 >/dev/null 2>&1; then
      nohup kglobalaccel6 >/dev/null 2>&1 &
    fi
  fi

  # --- Optionally remove Kitty package & its user config ---
  if [ "${WANT_REMOVE_KITTY}" -eq 1 ]; then
    if command -v kitty >/dev/null 2>&1; then
      log "Removing kitty..."
      need sudo pacman
      sudo pacman -Rns --noconfirm kitty || true
    fi
    if [ -d "$HOME/.config/kitty" ]; then
      log "Keeping ~/.config/kitty (user config). Remove manually if you wish."
    fi
  fi

  # --- Final checks ---
  log "konsole path: $(command -v konsole || echo 'not found')"
  log "Default terminal set to 'konsole' in kdeglobals."
  log "Shortcut written: Ctrl+Alt+T -> Konsole (kglobalshortcutsrc)."
  log "Done. If Ctrl+Alt+T doesn't work immediately, log out/in."
}

main "$@"
