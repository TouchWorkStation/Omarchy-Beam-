#!/usr/bin/env bash
#
# Lightweight tests for Omarchy Beam's content classification, preview
# sanitization, payload limits, and QR matrix generation.
#
# These are pure-logic tests: they source bin/omarchy-beam and call its
# functions directly, so they need only bash + qrencode (no Wayland, no shell).
# If zbarimg is installed, an extra round-trip test decodes the generated
# matrix to confirm it is actually scannable.
#
# Run:  test/beam_test.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/bin/omarchy-beam"

pass=0
fail=0

ok()   { printf '  \033[32mok\033[0m   %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail + 1)); }

# assert_kind <content> <expected-kind> <expected-label>
assert_kind() {
  local content="$1" want_kind="$2" want_label="$3"
  classify "$content"
  if [[ "$BEAM_KIND" == "$want_kind" && "$BEAM_LABEL" == "$want_label" ]]; then
    ok "classify: [$content] -> $BEAM_KIND / $BEAM_LABEL"
  else
    bad "classify: [$content] -> $BEAM_KIND / $BEAM_LABEL (wanted $want_kind / $want_label)"
  fi
}

# assert_payload <content> <expected-payload>
assert_payload() {
  local content="$1" want="$2"
  classify "$content"
  if [[ "$BEAM_PAYLOAD" == "$want" ]]; then
    ok "payload: [$content] -> [$BEAM_PAYLOAD]"
  else
    bad "payload: [$content] -> [$BEAM_PAYLOAD] (wanted [$want])"
  fi
}

echo "Classification"
assert_kind "https://github.com/omacom/omarchy" url  "Scan to open"
assert_kind "http://192.168.1.20:8080"          url  "Scan to open"
assert_kind "sudo pacman -S docker"             text "Scan to copy"
assert_kind "user@example.com"                  email "Scan to email"
assert_kind "mailto:user@example.com"           email "Scan to email"
assert_kind "tel:+15555555555"                  tel  "Scan to call"
assert_kind "WIFI:T:WPA;S:MyNet;P:secret;;"     wifi "Scan to join"
assert_kind "just some words"                   text "Scan to copy"
assert_kind $'multi\nline\ntext'                text "Scan to copy"
# A URL with a space is not a URL.
assert_kind "https://foo bar"                   text "Scan to copy"

echo "Payload rewriting"
assert_payload "user@example.com"     "mailto:user@example.com"
assert_payload "mailto:a@b.com"       "mailto:a@b.com"
assert_payload "https://x.test/a"     "https://x.test/a"
assert_payload $'has\ntrailing\n'     $'has\ntrailing\n'   # text kept verbatim

echo "Preview sanitization + truncation"
p="$(preview_of "https://github.com/omacom/omarchy" url)"
[[ "$p" == "github.com/omacom/omarchy" ]] && ok "preview strips scheme" || bad "preview strips scheme (got [$p])"
long="$(printf 'x%.0s' {1..200})"
p="$(preview_of "$long" text)"
(( ${#p} <= 42 )) && ok "preview truncated to <=42 chars (${#p})" || bad "preview truncation (${#p})"
p="$(preview_of $'first line\nsecond line' text)"
[[ "$p" == "first line" ]] && ok "preview keeps first line only" || bad "preview first-line (got [$p])"
p="$(preview_of "WIFI:T:WPA;S:HomeNet;P:pw;;" wifi)"
[[ "$p" == "Wi-Fi: HomeNet" ]] && ok "preview extracts SSID" || bad "preview SSID (got [$p])"

echo "QR matrix"
m="$(printf '%s' "https://github.com/omacom/omarchy" | qr_matrix)"
rows=$(grep -c . <<<"$m")
cols=$(head -1 <<<"$m"); cols=${#cols}
if [[ "$rows" -gt 0 && "$rows" == "$cols" ]] && ! grep -qvE '^[01]+$' <<<"$m"; then
  ok "matrix is a square 0/1 grid (${rows}x${cols})"
else
  bad "matrix square/0-1 (${rows}x${cols})"
fi

# Optional: prove the matrix is scannable by rebuilding an image and decoding.
if command -v zbarimg >/dev/null 2>&1; then
  payload="https://github.com/omacom/omarchy"
  m="$(printf '%s' "$payload" | qr_matrix)"
  tmp="$(mktemp --suffix=.pbm)"
  {
    cols=$(head -1 <<<"$m"); cols=${#cols}
    rows=$(grep -c . <<<"$m")
    echo "P1"; echo "$((cols * 6)) $((rows * 6))"
    while IFS= read -r r; do
      for _ in 1 2 3 4 5 6; do
        out=""; for ((i = 0; i < ${#r}; i++)); do c="${r:i:1}"; out+="$c $c $c $c $c $c "; done
        echo "$out"
      done
    done <<<"$m"
  } >"$tmp"
  decoded="$(zbarimg -q --raw "$tmp" 2>/dev/null)"; decoded="${decoded%$'\n'}"
  rm -f "$tmp"
  [[ "$decoded" == "$payload" ]] && ok "matrix decodes back to the payload" || bad "matrix decode (got [$decoded])"
else
  echo "  -- zbarimg not installed; skipping scannability round-trip"
fi

echo
echo "Passed: $pass   Failed: $fail"
[[ "$fail" -eq 0 ]]
