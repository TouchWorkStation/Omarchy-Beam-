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

echo "Text mode (opt-in BEAM_TEXT_MODE)"
BEAM_TEXT_MODE=plain classify "hello world"
[[ "$BEAM_PAYLOAD" == "hello world" && "$BEAM_DISPLAY" == "hello world" ]] \
  && ok "plain mode keeps raw text" || bad "plain mode (got [$BEAM_PAYLOAD])"
BEAM_TEXT_MODE=sms classify "hello world"
[[ "$BEAM_KIND" == "text" && "$BEAM_PAYLOAD" == "sms:?body=hello%20world" && "$BEAM_DISPLAY" == "hello world" ]] \
  && ok "sms mode wraps text, display kept" || bad "sms mode (got [$BEAM_PAYLOAD] / [$BEAM_DISPLAY])"
BEAM_TEXT_MODE=mailto classify $'multi\nline'
[[ "$BEAM_PAYLOAD" == "mailto:?body=multi%0Aline" ]] \
  && ok "mailto mode url-encodes newlines" || bad "mailto mode (got [$BEAM_PAYLOAD])"
BEAM_TEXT_MODE=sms classify "https://x.test/a"
[[ "$BEAM_KIND" == "url" && "$BEAM_PAYLOAD" == "https://x.test/a" ]] \
  && ok "text mode does not touch URLs" || bad "url under text mode (got [$BEAM_PAYLOAD])"
BEAM_TEXT_MODE=bogus classify "plain again"
[[ "$BEAM_PAYLOAD" == "plain again" ]] \
  && ok "unknown mode falls back to plain" || bad "bad-mode fallback (got [$BEAM_PAYLOAD])"
# The sms URI must decode back to the original text.
if command -v python3 >/dev/null 2>&1; then
  BEAM_TEXT_MODE=sms classify $'copy me\nplease'
  body="${BEAM_PAYLOAD#sms:?body=}"
  dec="$(python3 -c 'import sys,urllib.parse; sys.stdout.write(urllib.parse.unquote(sys.argv[1]))' "$body")"
  [[ "$dec" == $'copy me\nplease' ]] && ok "sms body decodes to the original text" || bad "sms decode (got [$dec])"
fi
unset BEAM_TEXT_MODE

echo "Preview sanitization + truncation"
p="$(preview_of "https://github.com/omacom/omarchy" url)"
[[ "$p" == "github.com/omacom/omarchy" ]] && ok "preview strips scheme" || bad "preview strips scheme (got [$p])"
# URLs and other short kinds stay on one line (<=42 chars).
p="$(preview_of "https://example.com/$(printf 'a%.0s' {1..100})" url)"
(( ${#p} <= 42 )) && ok "url preview truncated to <=42 chars (${#p})" || bad "url preview truncation (${#p})"
# Plain text gets a longer, wrapped allowance so it is readable off the overlay.
long="$(printf 'x%.0s' {1..400})"
p="$(preview_of "$long" text)"
(( ${#p} <= 180 && ${#p} > 42 )) && ok "text preview truncated to <=180 chars (${#p})" || bad "text preview truncation (${#p})"
# Multiline text is flattened to a single line (the overlay wraps it visually).
p="$(preview_of $'first line\nsecond line' text)"
[[ "$p" == "first line second line" ]] && ok "text preview flattens newlines" || bad "text preview flatten (got [$p])"
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

echo "Beam Link — count resolution"
[[ "$(XDG_CONFIG_HOME=/nonexistent resolve_link_count_default)" == "5" ]] \
  && ok "link count defaults to 5" || bad "link default count"
_cfg="$(mktemp -d)"; mkdir -p "$_cfg/omarchy-beam"; echo 12 >"$_cfg/omarchy-beam/link-count"
[[ "$(XDG_CONFIG_HOME=$_cfg resolve_link_count_default)" == "12" ]] \
  && ok "link count reads config file" || bad "link config count"
rm -rf "$_cfg"

echo "Beam Link — server + link-mode emit"
if command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  _st="$(mktemp -d)"; _rt="$(mktemp -d)"
  mkdir -p "$_st/omarchy"
  cat >"$_st/omarchy/clipboard-history.json" <<'JSON'
[{"type":"text","text":"first entry"},{"type":"text","text":"second <b>&</b>"},{"type":"image","path":"/x.png"},{"type":"text","text":"third entry"}]
JSON
  ldir="$_rt/omarchy-beam"; mkdir -p "$ldir"
  XDG_STATE_HOME="$_st" "$ROOT/bin/omarchy-beam-serve" --count 2 --ttl 15 \
    --url-file "$ldir/link.url" --pid-file "$ldir/link.pid" >/dev/null 2>&1 &
  for _ in $(seq 1 40); do [[ -s "$ldir/link.url" ]] && break; sleep 0.05; done
  url="$(cat "$ldir/link.url" 2>/dev/null)"
  if [[ -n "$url" ]]; then
    page="$(curl -s "$url")"
    [[ "$(grep -c 'class="item"' <<<"$page")" == "2" ]] && ok "server serves requested count (2, images skipped)" || bad "server count"
    grep -q '&lt;b&gt;' <<<"$page" && ! grep -q '<b>&</b>' <<<"$page" && ok "server HTML-escapes entries" || bad "server escaping"
    [[ "$(curl -s -o /dev/null -w '%{http_code}' "${url%/*}/wrongtoken")" == "404" ]] && ok "server rejects wrong token (404)" || bad "server token check"
    # Link-mode emit shows a QR of the URL.
    out="$(XDG_RUNTIME_DIR="$_rt" "$ROOT/bin/omarchy-beam" --emit | head -1)"
    [[ "$out" == meta$'\t'ok$'\t'link$'\t'* ]] && ok "emit shows link QR when server is up" || bad "link emit (got [$out])"
    # link-stop tears everything down.
    XDG_RUNTIME_DIR="$_rt" "$ROOT/bin/omarchy-beam" --link-stop
    sleep 0.3
    [[ ! -e "$ldir/link.url" ]] && ok "link-stop removes state + kills server" || bad "link-stop cleanup"
  else
    bad "server did not publish a URL"
  fi
  rm -rf "$_st" "$_rt"
else
  echo "  -- python3/curl not available; skipping Beam Link server test"
fi

echo
echo "Passed: $pass   Failed: $fail"
[[ "$fail" -eq 0 ]]
