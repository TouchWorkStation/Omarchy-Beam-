#!/usr/bin/env bash
#
# Clean, safe teardown for Omarchy Beam.
#
# Removes only what Beam created: the `omarchy-beam` PATH symlink (only if it
# points at this plugin) and Beam's runtime state. It never edits your Hyprland
# config and never deletes your clipboard history. The plugin folder itself is
# removed by `omarchy plugin remove beam`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
DEST="$BIN_DIR/omarchy-beam"

green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

# Remove the PATH symlink only if it points back into this plugin (don't touch
# an unrelated binary a user may have named the same).
if [[ -L "$DEST" ]]; then
  target="$(readlink -f "$DEST" 2>/dev/null || true)"
  if [[ "$target" == "$SCRIPT_DIR/bin/omarchy-beam" ]]; then
    rm -f "$DEST"
    green "Removed $DEST"
  else
    yellow "Left $DEST alone (it points elsewhere: ${target:-unknown})"
  fi
elif [[ -e "$DEST" ]]; then
  yellow "Left $DEST alone (not a symlink created by Beam)"
fi

# Remove Beam's runtime state (the one-shot payload temp dir). Never persisted data.
rm -rf "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/omarchy-beam" 2>/dev/null || true

green "Omarchy Beam CLI unlinked."
cat <<EOF

To finish removing Beam:
  • Delete the keybinding line(s) from ~/.config/hypr/bindings.lua, then: hyprctl reload
  • Remove the plugin itself:            omarchy plugin remove beam
  • (Optional) remove your preferences:  rm -rf ~/.config/omarchy-beam

Your clipboard and its history are untouched.
EOF
