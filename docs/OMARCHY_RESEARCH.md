# Omarchy plugin architecture — research notes

This document records what Omarchy Beam was built against, so the plugin tracks
the *current* Omarchy plugin system rather than an assumption from older docs.

> **Where this was researched.** The build/CI container this was developed in is
> not itself an Omarchy machine (it's Ubuntu, with no `omarchy` CLI, Quickshell,
> or Wayland session). So the architecture below was verified against the
> upstream Omarchy source at the tag the current release ships from — the
> `quattro` branch of `omacom/omarchy` (mirror: `basecamp/omarchy`),
> **Omarchy version `4.0.0.alpha`** — and Beam is modeled directly on a working
> first-party plugin from that tree. Everything that does not require a live
> Wayland session (content classification, payload limits, QR generation and
> scannability, the CLI, the manifest, and the CLI↔QML protocol) was executed
> and tested here; the on-screen overlay must be verified on a real Omarchy box
> (see the checklist at the end).

## The shell

The Omarchy desktop runs as a single long-lived Quickshell process,
**`omarchy-shell`**. Almost everything on screen is a *plugin* inside that one
process: the bar, the drop-down panels, fullscreen overlays (emoji picker,
clipboard manager), the menu, the lock screen, the polkit dialog, and headless
services. Plugins are loaded when summoned and share the running process instead
of spawning a second Quickshell.

## Plugins

Every plugin is a directory with a `manifest.json` at its root plus the QML files
it references.

- **Built-in** plugins live in `$OMARCHY_PATH/shell/plugins/`.
- **Third-party** plugins live in `~/.config/omarchy/plugins/<plugin-id>/` and
  are installed with `omarchy plugin add <git-url>` (a git clone).

### manifest.json

Validated by `shell/services/PluginRegistry.qml` and, identically, by the CLI
`omarchy plugin validate`. The schema (from `bin/omarchy-plugin-validate`):

- `schemaVersion` — must be the JSON number `1`.
- `id`, `name`, `version`, `kinds`, `entryPoints` — all required.
- `id` — matches `^[A-Za-z0-9][A-Za-z0-9._-]*$`, contains no `..`, and **may not
  use the reserved `omarchy.*` namespace** (that's for first-party plugins).
- `kinds` — a non-empty array. One of:
  `bar`, `bar-widget`, `panel`, `overlay`, `menu`, `service`.
- `entryPoints` — an object mapping each kind to a **relative** QML path that
  exists, contains no `..`, and is not absolute.
- Each declared kind must have its matching entry point
  (`overlay` → `entryPoints.overlay`, `panel` → `entryPoints.panel`, …).
- **No symlinks** anywhere inside the plugin folder (except `.git`).
- Optional: `author`, `description`, `keepLoaded` (keep the plugin's window
  mounted between summons), and, for bar widgets, a `barWidget` block.

Beam's manifest:

```json
{
  "schemaVersion": 1,
  "id": "beam",
  "name": "Omarchy Beam",
  "version": "0.1.0",
  "author": "TouchWorkStation",
  "description": "Beam your clipboard to any device — copy, press a shortcut, scan a QR code.",
  "kinds": ["overlay"],
  "entryPoints": { "overlay": "qml/Beam.qml" }
}
```

`omarchy plugin validate .` exits `0` against this repo.

### Summoning plugins from the CLI

`omarchy-shell` talks to the running shell over IPC:

```bash
omarchy-shell shell summon <id> '<jsonPayload>'   # load + open
omarchy-shell shell hide   <id>                   # close
omarchy-shell shell toggle <id> '<jsonPayload>'   # open if closed, close if open
omarchy-shell shell listPlugins
```

The shell calls the plugin's `open(payloadJson)` / `close()` methods. Overlays,
panels, and menus all follow this pattern. The template `bindings.lua` shipped by
Omarchy even shows the idiom for a key:

```lua
o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")
```

Beam uses `omarchy-shell shell toggle beam '{}'`, so pressing the shortcut again
closes the overlay instead of stacking a second one.

## The reference implementation: Wi-Fi QR

Omarchy already ships a QR overlay — the **Wi-Fi share card**, plugin
`omarchy.wifiqr` (`shell/plugins/panels/wifiqr/`). Beam is modeled directly on
it, because it is the closest thing in the tree and it is proven to render and
scan on this Omarchy version. Key techniques adopted from it:

1. **Fullscreen `PanelWindow` on the overlay layer** with a deep near-black
   scrim (`WlrLayershell.layer: Overlay`, `keyboardFocus: Exclusive`). `Esc` or a
   click on the scrim dismisses; clicks on the card are swallowed.
2. **QR rendered as native rectangles, never an image file.** A helper CLI emits
   a square `0/1` module matrix, and the QML draws one `Rectangle` per module.
   This is crisp, theme-independent, and avoids temp-file/cache races entirely.
   Omarchy's own helper is `bin/omarchy-network-qr`; it builds the matrix with
   `qrencode --type ASCII --margin 4` and collapses each 2-char ASCII cell to one
   `0`/`1`. Beam's `omarchy-beam --emit` uses the identical technique.
3. **The clipboard/secret never travels through the IPC payload.** wifiqr's QML
   runs `omarchy-network-qr` itself; Beam's QML runs `omarchy-beam --emit`, which
   reads the clipboard directly. The summon payload stays `{}`.
4. **A `Model.js` parser** turns the helper's `meta` + matrix output into
   structured data and refuses a non-square / non-binary matrix rather than
   drawing a code that cannot scan.

Beam differs from wifiqr in two deliberate ways: it uses the **`overlay`** kind
(it is a fullscreen surface like the emoji picker, not a network panel), and it
draws a **themed card** (using the shared `Color.menu.*` surface tokens, like the
emoji overlay) around a **fixed-white QR canvas** — the card honors the active
theme while the QR keeps guaranteed contrast and a quiet zone for scanning.

## Theming API (used by Beam)

- `qs.Commons` singletons: **`Style`** (spacing via `Style.space(n)`, typography
  `Style.font.*`, `Style.cornerRadius`) and **`Color`** (roles `accent`,
  `foreground`, `background`, `muted`, `urgent`, and surface groups such as
  `Color.menu.background` / `Color.menu.border`). These re-derive from the active
  theme, so Beam restyles automatically when the theme changes.

## Keybindings

Omarchy 4 configures Hyprland in Lua. User keybindings go in
**`~/.config/hypr/bindings.lua`** using `o.bind(keys, description, command)` (or
`o.rebind` to replace a default, `hl.unbind` to remove one). List current
bindings with `omarchy menu keybindings --print`.

The recommended **`SUPER + SHIFT + Q`** is free on a default install
(`SUPER + Q` = close window, `SUPER + CTRL + Q` = calculator), so Beam does not
overwrite anything. Beam never edits this file itself — it only documents the
one line to add.

## Dependencies present in Omarchy

- **`qrencode`** — used by the shipped `omarchy-network-qr`, so it is already the
  established QR tool in Omarchy. Beam reuses it.
- **`wl-clipboard`** (`wl-paste`) — the standard Wayland clipboard tool.
- **`omarchy-shell`** — to display the overlay.

Beam adds no new runtime dependencies beyond these.

## What must still be checked on a real Omarchy machine

Verified here (headless): classification, payload limits, QR generation +
decode round-trip, the CLI, `omarchy plugin validate`, and the `--emit` ⇆
`Model.js` protocol. Verify on hardware:

- [ ] `omarchy plugin add <this repo>` installs and enables it.
- [ ] `SUPER + SHIFT + Q` opens the overlay over the current wallpaper/theme.
- [ ] The QR scans from a phone at a normal viewing distance.
- [ ] `Esc` and a scrim click both dismiss; re-pressing toggles cleanly.
- [ ] The card picks up a couple of different Omarchy themes correctly.
- [ ] Empty clipboard shows the "Nothing to Beam" notification (no overlay).
