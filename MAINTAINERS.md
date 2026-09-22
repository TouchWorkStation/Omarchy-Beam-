# Maintainer Note

**Plugin:** Omarchy Beam (`beam`)
**Maintainer:** TouchWorkStation
**Repository:** https://github.com/TouchWorkStation/Omarchy-Beam-
**Current release:** v0.6.0
**Status:** Stable and actively maintained

Beam turns the current clipboard into a scannable QR code shown in a native
Omarchy overlay — copy, press a shortcut, scan with your phone. It ships as an
Omarchy shell plugin and is distributed as a public git repository (install with
`omarchy plugin add`).

## Scope

The scope is intentionally small and will stay that way:

- **QR mode:** classify a link or the clipboard (URL / text / email / tel /
  Wi-Fi) and render a scannable QR in a themed overlay. Also a terminal pipe
  mode and opt-in `sms` / `mailto` text encodings.

Out of scope by design: any server or network feature, cloud sync, accounts,
pairing, device discovery, file transfer, a persistent daemon, or a settings UI.
Beam is fully local — the data only ever leaves the machine visually, through the
QR code.

## Compatibility

- Built against the **Omarchy 4.x (quattro)** shell plugin API — `manifest.json`
  `schemaVersion: 1`, `overlay` kind. Passes `omarchy plugin validate .`.
- **Requires:** `omarchy-shell`, `wl-clipboard` (`wl-paste`), `qrencode`.

## Support

- **Bugs and feature requests:** please open a GitHub issue with your Omarchy
  version (`omarchy --version` or the shell version), the exact command run, and
  the output of `omarchy-beam --version`.
- **Response expectations:** this is a community plugin maintained on a
  best-effort basis. PRs are welcome; see the README's Contributing section
  (`omarchy plugin validate .` and `test/beam_test.sh` must pass).

## Known limitations

- **QR mode:** verified on a live Omarchy session (see `screenshots/`).
- **Plain-text QR:** a phone's stock camera treats non-actionable text as a web
  search; use a scanner that offers Copy (Google Lens / iOS Camera), or one of
  the opt-in `sms`/`mailto` text modes. A QR cannot write to a phone clipboard
  on its own.

## Security & privacy posture

- **Fully local, no network at all:** clipboard contents never leave the machine
  except visually, as the QR image. Beam opens no ports and runs no server. No
  telemetry, network requests, accounts, history, or logging of clipboard
  contents. Clipboard data is only ever piped to `qrencode` on stdin — never
  interpolated into a shell command, executed, or evaluated.
- Report security concerns privately by opening a minimal GitHub issue asking
  for a contact channel, rather than posting exploit detail publicly.

## Versioning & releases

- Semantic Versioning, pre-1.0 (minor = features, patch = fixes).
- The **default branch is the release channel** — `omarchy plugin add` installs
  from it, so `main` is always kept in a validating, installable state.
- Keep the version in sync across `manifest.json` and `bin/omarchy-beam`.

### Cutting a release

1. Bump the version in `manifest.json` and `bin/omarchy-beam`.
2. `omarchy plugin validate .` → must exit 0.
3. `test/beam_test.sh` → must pass.
4. Update `README.md` / `screenshots/` if behavior or UI changed.
5. Merge to `main`; optionally tag `vX.Y.Z` and draft a GitHub release.

## Credits

Authored by TouchWorkStation, built with Claude Code. Modeled on Omarchy's
first-party Wi-Fi QR overlay; see `docs/OMARCHY_RESEARCH.md`.
