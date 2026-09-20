# Security Policy

## Reporting a vulnerability

Please **do not** post exploit details in a public issue. Open a minimal GitHub
issue on this repository asking for a private contact channel, and a maintainer
will follow up. Include only what's needed to establish scope (affected version,
platform) until a private channel is set up.

## Security posture

Omarchy Beam is designed to do one thing safely: turn a link (or clipboard text)
into a scannable QR code.

- **Local by default.** The core "links → QR" mode makes **no network requests**,
  writes **no temp files**, keeps **no history**, and logs nothing.
- **No privilege escalation.** Beam never runs `sudo`/`pkexec` and never
  installs, upgrades, or removes packages. If a dependency is missing it prints
  the package name for you to install — it does not run a package manager.
- **No configuration is overwritten.** Beam never edits your Hyprland config; it
  only prints the keybinding line for you to add. `install.sh` only symlinks the
  CLI into `~/.local/bin`; `uninstall.sh` only removes what Beam created.
- **Untrusted input.** Clipboard/argument data is only ever passed to `qrencode`
  on stdin — never interpolated into a shell command, executed, or evaluated. A
  payload size cap (`BEAM_MAX_BYTES`) bounds it.

## Beam Link (optional, work in progress)

`--link` / `--secret` start a small local `python3` web server so a phone can
copy clipboard **history**. It is **opt-in**, off unless you invoke it, and can
be disabled entirely (`BEAM_DISABLE_LINK=1` or
`~/.config/omarchy-beam/links-only`). When running it:

- binds this machine's **LAN** address only (never a third-party/cloud service);
- requires an **unguessable token** in the URL (constant-time compared);
- **self-expires** on a TTL, and in `--secret` mode serves the page **once** then
  shuts down;
- escapes all served content and sets a restrictive `Content-Security-Policy`;
- never logs requests or clipboard contents (except opt-in `--verbose`, which
  logs only method/client/status — never the token or content).

Because it serves over plain HTTP on your LAN, treat it as suitable for your own
trusted network, not a hostile one. End-to-end-encrypted, cross-network transfer
is on the roadmap.

## Supported versions

Beam is pre-1.0; fixes land on the latest release. Please report against the
newest version (`omarchy-beam --version`).
