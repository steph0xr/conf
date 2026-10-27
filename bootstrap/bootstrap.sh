#!/usr/bin/env bash
#
# Provision a fresh machine into "my" machine:
#   packages  ->  system tweaks  ->  link dotfiles (rcm)
#
# Safe to re-run: every step is idempotent.
# Usage:  ./bootstrap/bootstrap.sh
#
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(dirname "$here")"

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. apt packages (list lives in packages.txt)
# ---------------------------------------------------------------------------
log "Installing apt packages"
sudo apt update
mapfile -t pkgs < <(grep -vE '^\s*#|^\s*$' "$here/packages.txt")
sudo apt install -y "${pkgs[@]}"

# ---------------------------------------------------------------------------
# 2. passwordless sudo  (drop-in file, validated -- never hand-edit visudo)
# ---------------------------------------------------------------------------
sudo_file="/etc/sudoers.d/90-${USER}-nopasswd"
if [ ! -f "$sudo_file" ]; then
  log "Enabling passwordless sudo for $USER"
  echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "$sudo_file" >/dev/null
  sudo chmod 440 "$sudo_file"
  sudo visudo -cf "$sudo_file"   # validate; bad syntax => file ignored, not lockout
fi

# ---------------------------------------------------------------------------
# 3. serial / USB-programmer access
#    dialout -> /dev/ttyUSB*, /dev/ttyACM* (STM32, EIO-IS200, etc.)
#    plugdev -> hotplug USB devices
#    (log out / back in for group changes to take effect)
# ---------------------------------------------------------------------------
log "Adding $USER to dialout,plugdev"
sudo usermod -aG dialout,plugdev "$USER"

# ---------------------------------------------------------------------------
# 4. Tilix as default terminal + restore its config
# ---------------------------------------------------------------------------
if command -v tilix >/dev/null; then
  log "Setting Tilix as default x-terminal-emulator"
  sudo update-alternatives --set x-terminal-emulator "$(command -v tilix)" || true
  if [ -f "$here/Tilix.ini" ] && command -v dconf >/dev/null; then
    log "Loading Tilix dconf config"
    dconf load /com/gexperts/Tilix/ < "$here/Tilix.ini"
  fi
fi

# ---------------------------------------------------------------------------
# 5. link the dotfiles with rcm
#    DOTFILES_DIRS points rcm at this repo's .dotfiles/ (see ~/.rcrc)
# ---------------------------------------------------------------------------
log "Linking dotfiles (rcup)"
DOTFILES_DIRS="$repo/.dotfiles" rcup -v

# rcm skips dot-prefixed files in nested dirs, so it can't manage these
# (they must stay named .gdbinit/.exrc/.commands.py). Link them by hand.
log "Linking espressif configs (rcm can't manage dotted nested files)"
esp_src="$repo/.dotfiles/tag-espressif/config/espressif"
mkdir -p "$HOME/.config/espressif"
for f in .gdbinit .exrc .commands.py; do
  ln -sfn "$esp_src/$f" "$HOME/.config/espressif/$f"
done

log "Done. Log out and back in for group membership to apply."

# ---------------------------------------------------------------------------
# Manual steps that resist scripting (left as a checklist on purpose):
#   - screensaver/lock preferences:
#       gsettings get org.gnome.desktop.screensaver ubuntu-lock-on-suspend
# ---------------------------------------------------------------------------
