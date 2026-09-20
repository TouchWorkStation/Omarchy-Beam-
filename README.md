# Omarchy Beam

**Beam your clipboard to any device.**

Copy something on your Omarchy computer, press a shortcut, and a QR code appears
in a clean, native overlay. Scan it with your phone — the link opens, the text
copies, the number dials. That's the whole thing.

```
Copy  →  Super + Shift + Q  →  Scan
```

No pairing. No account. No cloud.

---

## Demo

A centered card on a dark scrim, styled with your current Omarchy theme —
running here with the repo URL on the clipboard:

<p align="center">
  <img src="screenshots/overlay.jpg" alt="Omarchy Beam overlay: a QR code labelled BEAM with the clipboard URL and SCAN TO OPEN" width="320">
</p>

Prefer the terminal? Pipe text straight to a scannable code without touching your
clipboard:

```bash
echo "https://github.com/omacom/omarchy" | omarchy-beam -
```

## Why Beam?

Moving a URL, a command, a Wi-Fi password, or a phone number from your desktop to
your phone is annoyingly hard for something so small. The usual answers are
messaging yourself, email drafts, or a syncing service — all of which mean
accounts, apps, and your data leaving the machine.

Beam does the obvious thing instead: it shows the data as a QR code on your own
screen. Your phone's camera does the rest. Nothing is transmitted, stored, or
uploaded — the information travels as photons, from your monitor to your camera.

## Installation

Beam is an Omarchy shell plugin.

```bash
omarchy plugin add https://github.com/TouchWorkStation/Omarchy-Beam-.git --enable
```

Then put the CLI on your PATH and see the keybinding to add:

```bash
~/.config/omarchy/plugins/beam/install.sh
```

`install.sh` only symlinks `omarchy-beam` into `~/.local/bin` and prints the
shortcut line — it never edits your Hyprland config.

<details>
<summary>Manual install (without the plugin manager)</summary>

```bash
git clone https://github.com/TouchWorkStation/Omarchy-Beam-.git \
  ~/.config/omarchy/plugins/beam
~/.config/omarchy/plugins/beam/install.sh
omarchy-shell shell rescanPlugins
omarchy-shell shell setPluginEnabled beam true
```
</details>

## Usage

1. Copy anything (a URL, a command, an email, a phone number, a Wi-Fi QR string).
2. Press **Super + Shift + Q** (or run `omarchy-beam`).
3. Scan the QR code with your phone.
4. Press **Esc** or click outside the card to close. Press the shortcut again to
   toggle it.

```bash
omarchy-beam               # toggle the overlay for the current clipboard
omarchy-beam --help
omarchy-beam --version
echo "text" | omarchy-beam -   # render a QR in the terminal, clipboard untouched
```

## Keyboard shortcut

`SUPER + SHIFT + Q` is unbound on a stock Omarchy install, so Beam does **not**
overwrite anything. Add it yourself in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + Q", "Beam clipboard", "omarchy-beam")
```

Reload with `hyprctl reload`. Prefer a different key? Check what's taken first
with `omarchy menu keybindings --print`, then use `o.rebind(...)` if you're
replacing an existing binding. The command `omarchy-beam` always works directly,
with or without a shortcut.

## Supported content

Beam classifies the clipboard automatically and shows the matching action:

| Clipboard                         | Detected as | Action shown   |
| --------------------------------- | ----------- | -------------- |
| `https://github.com/omacom/omarchy` | URL       | **Scan to open** |
| `sudo pacman -S docker`           | Plain text  | **Scan to copy** |
| `user@example.com` / `mailto:…`   | Email       | **Scan to email** |
| `tel:+15555555555`                | Telephone   | **Scan to call** |
| `WIFI:T:WPA;S:MyNet;P:secret;;`   | Wi-Fi QR    | **Scan to join** |

Detection is simple and deterministic — no AI, no guessing, no network.

### Copying plain text on your phone

A plain-text QR has no built-in action, so a phone's **stock Camera** treats it
as a web search instead of offering to copy it. That's a phone-OS behavior, not
a Beam limitation. Your options:

- **Use a scanner that copies text.** Google Lens, or a free open-source QR app
  like [Binary Eye](https://f-droid.org/packages/de.markusfisch.android.binaryeye/)
  (enable *Copy to clipboard* for true auto-copy). The saved-photo long-press
  also surfaces a Copy button.
- **Read it off the overlay.** Beam shows the full text under the QR.
- **Make the stock Camera prefill it (opt-in).** Set a text mode so plain text is
  encoded as a draft the camera *does* act on — nothing is sent, still 100%
  local:

  | Mode     | Scanning plain text opens…                    |
  | -------- | --------------------------------------------- |
  | `plain`  | raw text QR (default)                         |
  | `sms`    | Messages, with the text prefilled in the body |
  | `mailto` | Mail, with the text prefilled in the body     |

  Enable it with a config file (read by the overlay too):

  ```bash
  mkdir -p ~/.config/omarchy-beam
  echo mailto > ~/.config/omarchy-beam/text-mode   # or: sms
  ```

  Or per-run with the `BEAM_TEXT_MODE` environment variable (it overrides the
  file). Only plain text is affected — URLs, email, tel, and Wi-Fi are untouched.
  A QR can never write to a phone's clipboard on its own; this just gets the
  text somewhere copyable without a scanner app.

## Beam Link (opt-in) — copy from a page instead of a QR

Some things don't fit a QR, or you want to copy *history*, not just one item.
**Beam Link** serves your recent clipboard entries as a small web page **on your
own machine**, reachable over your Wi-Fi:

```bash
omarchy-beam --link        # asks how many entries to share, then shows a QR
omarchy-beam --link 10     # share the last 10 (skip the prompt)
omarchy-beam --link current # just the current clipboard
omarchy-beam --link all    # full history
```

Scan the QR (any camera — it's a normal URL) → your phone opens a page listing
those entries, each with a **Copy** button and tap-to-select. Bind it to a key
too, e.g.:

```lua
o.bind("SUPER + SHIFT + V", "Beam Link", "omarchy-beam --link")
```

**How it stays local:** the page is served by a tiny web server running on your
computer, bound to your LAN address behind an unguessable token in the URL. It
**self-expires** after a few minutes (`BEAM_LINK_TTL`, default 180s) and stops
when you close the overlay. Nothing is uploaded to any cloud.

**Know the trade-offs** (that's why it's opt-in, never the default):
- Phone and desktop must be on the **same Wi-Fi**.
- It exposes clipboard **history** to anyone who has the link while it's live.
- The one-tap Copy button is best-effort over plain `http` (browsers restrict
  the clipboard API on non-`https` origins); tap-to-select always works.
- Reads Omarchy's existing clipboard history
  (`~/.local/state/omarchy/clipboard-history.json`); if that's empty it serves
  just the current clipboard. Requires `python3`. The count picker uses
  `walker` (or `fuzzel`/`wofi`/…); with none installed it uses a default of 5
  (set it in `~/.config/omarchy-beam/link-count`).
- The URL shows your auto-detected LAN IP. Detection prefers a real private LAN
  address and skips Tailscale/CGNAT (`100.64/10`) and loopback, so a VPN
  shouldn't hijack it. If it still picks the wrong one (Docker, several NICs),
  set it yourself: `export BEAM_LINK_HOST=192.168.x.y` (find it with
  `ip -4 addr`). The overlay prints the IP under the QR so you can check at a
  glance.

## Privacy

Privacy is the point.

- **Completely local.** In the default QR mode your clipboard never leaves the
  machine except visually, as the QR code you scan.
- **No** telemetry, analytics, API, cloud service, remote server, account, or
  database — ever.
- **The one network exception is Beam Link**, and only when *you* invoke it: it
  serves data over your own LAN (never a third-party/cloud), behind a tokened,
  self-expiring local URL. The default QR mode makes no network requests at all.
- **No temp files** for the clipboard: the QR is drawn as native rectangles in
  the shell, not written to disk.
- **Nothing logged.** Clipboard contents are never printed to logs.
- Clipboard data is treated as untrusted input — it is only ever passed to
  `qrencode` on stdin, never interpolated into a shell command, and is never
  executed or evaluated.

## Requirements

Everything below already ships with Omarchy:

- `omarchy-shell` (the Omarchy Quickshell desktop)
- `wl-clipboard` (`wl-paste`)
- `qrencode`
- `python3` — only for **Beam Link** (`--link`); the QR modes don't need it.

If a dependency is somehow missing, Beam tells you and how to install it:

```bash
sudo pacman -S qrencode wl-clipboard      # core
sudo pacman -S python                      # only if you use --link
```

## Troubleshooting

- **"omarchy-shell not found" / overlay doesn't appear** — Beam needs the Omarchy
  shell running. Confirm with `omarchy-shell shell ping`.
- **Nothing happens on the shortcut** — check the binding exists
  (`omarchy menu keybindings --print`) and that `omarchy-beam` is on your PATH
  (`command -v omarchy-beam`). Run `~/.config/omarchy/plugins/beam/install.sh`.
- **"Nothing to Beam"** — the clipboard is empty or holds a non-text item (like
  an image). Copy some text and try again.
- **"Too large to Beam"** — the clipboard is bigger than the payload limit
  (1200 bytes by default; raise it with `BEAM_MAX_BYTES`). Big payloads make a
  dense QR that phones can't reliably scan.
- **QR won't scan** — increase your screen brightness, and make sure the whole
  card is on screen. The QR is rendered fixed-white with a quiet zone precisely
  so it scans under any theme.
- **Scanning plain text does nothing on my phone** — a plain-text QR has no
  built-in action (unlike a URL, which opens, or `tel:`, which dials), so what
  happens depends on the scanner. Use **Google Lens** (Android) or the **stock
  iOS Camera** — both show the text with a **Copy** button. A basic third-party
  camera app may ignore non-URL codes. Beam also shows the full text under the
  QR on the overlay, so you can read or copy it directly on the desktop. (A QR
  cannot push text into a phone's clipboard on its own — that would require a
  URL and a server, which Beam deliberately avoids.)
- **Plugin not loading** — run `omarchy plugin validate .` in the plugin folder
  and `omarchy-shell shell rescanPlugins`.
- **"could not start the Beam Link server"** — run `omarchy-beam --link-doctor`.
  It starts the server in the foreground and prints its URL or the exact error
  (e.g. missing `python3`), plus your host's IP addresses. (Fixed in v0.3.5: on
  hosts with a VPN such as Tailscale, the server used to stall on a reverse-DNS
  lookup at bind time — update if you're on an older version.)
- **Beam Link page won't open on my phone** — check, in order:
  1. **Same Wi-Fi?** Phone and desktop must be on the same network (and not a
     "guest" SSID — those often isolate devices from each other).
  2. **Right IP?** Look at the address under the QR. Compare with `ip -4 addr`
     on the desktop. If it's a VPN/Docker/`127.` address, set the real one:
     `export BEAM_LINK_HOST=192.168.x.y` (and re-run, or put it in your shell
     profile / the keybind: `env BEAM_LINK_HOST=192.168.x.y omarchy-beam --link`).
  3. **Server up?** On the desktop, `curl -s -o /dev/null -w '%{http_code}\n' "<the URL under the QR>"` should print `200`.
  4. **Firewall?** If curl works locally but the phone times out, a firewall is
     blocking the port. Allow it, e.g. `sudo ufw allow from 192.168.0.0/16` (or
     your subnet). Omarchy has no firewall by default, so this is rare.

## Uninstall

Run the teardown helper (unlinks the CLI, stops any Beam Link server, clears
runtime state — it never edits your Hyprland config or your clipboard history):

```bash
~/.config/omarchy/plugins/beam/uninstall.sh
omarchy plugin remove beam
```

Then delete the Beam `o.bind(…)` line(s) from `~/.config/hypr/bindings.lua`,
`hyprctl reload`, and optionally `rm -rf ~/.config/omarchy-beam` to drop your
preferences.

## Contributing

Issues and PRs welcome. Before opening a PR:

```bash
omarchy plugin validate .   # manifest passes the shell's own schema
test/beam_test.sh           # classification, previews, limits, QR round-trip
```

Please keep V0.1 focused: **turn the current clipboard into a beautiful,
instantly scannable QR code.** See `docs/OMARCHY_RESEARCH.md` for how Beam maps
onto the current Omarchy plugin architecture.

## License

[MIT](LICENSE) © TouchWorkStation
