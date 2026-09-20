#!/usr/bin/env bash
#
# Optional convenience installer for Omarchy Beam.
#
# If you installed Beam with `omarchy plugin add`, the overlay already works —
# it finds the CLI next to itself. This script just puts `omarchy-beam` on your
# PATH (so you can run it and bind a key to it) and prints the keybinding you
# can add. It changes nothing else and never touches your Hyprland config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SRC:-$SCRIPT_DIR/bin/omarchy-beam}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
DEST="$BIN_DIR/omarchy-beam"

green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

[[ -f "$SRC" ]] || { echo "cannot find $SRC" >&2; exit 1; }

mkdir -p "$BIN_DIR"
ln -sf "$SRC" "$DEST"
chmod +x "$SRC"
green "Linked $DEST -> $SRC"

# Dependency check (informational only).
missing=()
command -v wl-paste  >/dev/null 2>&1 || missing+=("wl-clipboard")
command -v qrencode  >/dev/null 2>&1 || missing+=("qrencode")
if (( ${#missing[@]} )); then
  yellow "Missing dependencies: ${missing[*]}"
  echo   "  Install them with your package manager, e.g. pacman -S ${missing[*]}"
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) yellow "Note: $BIN_DIR is not on your PATH. Add it to use 'omarchy-beam' directly." ;;
esac

cat <<'EOF'

Add the keyboard shortcut by putting this in ~/.config/hypr/bindings.lua:

    o.bind("SUPER + SHIFT + Q", "Beam clipboard", "omarchy-beam")

Then reload Hyprland (Super + Escape, or `hyprctl reload`).

Run it now with:  omarchy-beam
EOF
