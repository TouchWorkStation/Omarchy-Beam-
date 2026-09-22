# Security Policy

## Reporting a vulnerability

Please **do not** post exploit details in a public issue. Open a minimal GitHub
issue on this repository asking for a private contact channel, and a maintainer
will follow up. Include only what's needed to establish scope (affected version,
platform) until a private channel is set up.

## Security posture

Omarchy Beam is designed to do one thing safely: turn a link (or clipboard text)
into a scannable QR code.

- **Fully local, no network at all.** Beam makes **no network requests**, opens
  **no ports**, runs **no server**, keeps **no history**, and logs nothing. Your
  data never leaves this machine except visually, through the QR code you scan.
- **No privilege escalation.** Beam never runs `sudo`/`pkexec` and never
  installs, upgrades, or removes packages. If a dependency is missing it prints
  the package name for you to install — it does not run a package manager.
- **No configuration is overwritten.** Beam never edits your Hyprland config; it
  only prints the keybinding line for you to add. `install.sh` only symlinks the
  CLI into `~/.local/bin`; `uninstall.sh` only removes what Beam created.
- **Untrusted input.** Clipboard/argument data is only ever passed to `qrencode`
  on stdin — never interpolated into a shell command, executed, or evaluated. A
  payload size cap (`BEAM_MAX_BYTES`) bounds it.
- **No persisted data.** `omarchy-beam <link>` writes a single one-shot payload
  file under `$XDG_RUNTIME_DIR/omarchy-beam` (mode 600, in a 700 directory) that
  the overlay consumes and deletes on read. Nothing else is written to disk, and
  the toggle/clipboard path writes nothing at all.

## Supported versions

Beam is pre-1.0; fixes land on the latest release. Please report against the
newest version (`omarchy-beam --version`).
