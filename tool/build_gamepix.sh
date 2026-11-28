#!/usr/bin/env bash
# Builds the GamePix upload bundle: build/gamepix/ and
# build/merge-camp-gamepix.zip. See docs/gamepix.md.
# The only third-party script is the GamePix SDK v3 (feature-gamepix-sdk):
# no other scripts, no external links, no other network requests (fonts
# included).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="$ROOT/build/gamepix"
ZIP="$ROOT/build/merge-camp-gamepix.zip"

rm -rf "$OUT" "$ZIP"
flutter build web --release \
  --base-href / \
  --no-web-resources-cdn \
  --dart-define=GAMEPIX=true \
  --output "$OUT"

INDEX="$OUT/index.html"
# GamePix serves the bundle from an unknown sub path: use a relative base.
perl -pi -e 's#<base href="/">#<base href="./">#' "$INDEX"
# Portal builds must not link out: drop the Bon-on hub nav bar and the space
# reserved for it (see feature-game-hub-navigation).
perl -0pi -e 's#\s*<nav class="games-nav-bar".*?</nav>##s' "$INDEX"
perl -pi -e 's#--games-nav-height: calc\([^;]*\);#--games-nav-height: 0px;#' "$INDEX"
# Template comments carry documentation URLs; they are not needed at runtime.
perl -0pi -e 's#<!--.*?-->\s*##gs' "$INDEX"
# GamePix SDK with manual lifecycle, loaded in <head> before the Flutter
# bootstrap so localStorage sync is active from the game's first read.
SDK_URL="https://integration.gamepix.com/sdk/v3/gamepix.sdk.js"
perl -pi -e "s#^(\\s*)</head>#\$1  <script>window.GamePixConfig = { lifecycle: 'manual' };</script>\n\$1  <script src=\"$SDK_URL\"></script>\n\$1</head>#" "$INDEX"

fail() { echo "error: $1" >&2; exit 1; }

grep -q '<base href="./">' "$INDEX" || fail "relative base href missing"
grep -q -e 'games-nav-bar"' -e 'bon-on.github.io' "$INDEX" && fail "hub navigation link still present in index.html"
grep -q -e '--games-nav-height: 0px;' "$INDEX" || fail "hub navigation height was not reset"
grep -qi 'crazygames' "$INDEX" && fail "CrazyGames reference found in index.html"
[ "$(grep -c -F "<script src=\"$SDK_URL\"></script>" "$INDEX")" = 1 ] || fail "GamePix SDK script missing or duplicated"
grep -q "window.GamePixConfig = { lifecycle: 'manual' };" "$INDEX" || fail "GamePix manual lifecycle config missing"
sdk_line=$(grep -n -m1 -F "$SDK_URL" "$INDEX" | cut -d: -f1 || true)
config_line=$(grep -n -m1 -F 'window.GamePixConfig' "$INDEX" | cut -d: -f1 || true)
boot_line=$(grep -n -m1 -F 'flutter_bootstrap.js"' "$INDEX" | cut -d: -f1 || true)
[ "$config_line" -lt "$sdk_line" ] && [ "$sdk_line" -lt "$boot_line" ] \
  || fail "GamePix config and SDK must precede flutter_bootstrap.js"
# The inlined engine loader embeds a gstatic CanvasKit fallback URL (dead code
# while useLocalCanvasKit is true, checked below) and a GitHub issue URL in a
# warning message; the GamePix SDK URL is checked above. Any other URL is an
# error.
sed -e 's#https://www.gstatic.com/flutter-canvaskit##g' \
    -e "s#$SDK_URL##g" \
    -e 's#https://github.com/flutter/flutter/issues/[0-9]*##g' "$INDEX" \
  | grep -q -E 'https?://' \
  && fail "outbound URL found in index.html"
grep -q '"useLocalCanvasKit":true' "$INDEX" "$OUT/flutter_bootstrap.js" \
  || fail "CanvasKit is not served locally"
grep -q 'name="viewport".*user-scalable=no' "$INDEX" || fail "viewport meta without user-scalable=no"
grep -q 'touch-action: none' "$INDEX" || fail "touch-action: none missing"

# No third-party SDK script anywhere in the bundle.
if grep -rIl -e 'crazygames-sdk' -e 'sdk.crazygames.com' "$OUT" >/dev/null 2>&1; then
  fail "CrazyGames SDK reference found in bundle"
fi
# The game code must not carry portal or outbound share links: the CrazyGames
# adapter and the Pages share link are tree-shaken (feature-next-goal-share).
[ -f "$OUT/main.dart.js" ] || fail "main.dart.js missing"
grep -qi 'crazygames' "$OUT/main.dart.js" && fail "CrazyGames string found in main.dart.js"
grep -q 'bon-on.github.io' "$OUT/main.dart.js" && fail "share link found in main.dart.js"
# Roboto must be bundled, otherwise Flutter fetches it from fonts.gstatic.com.
grep -q '"family":"Roboto"' "$OUT/assets/FontManifest.json" \
  || fail "Roboto missing from FontManifest.json"

# Debug symbol files are not needed at runtime.
find "$OUT" -name '*.symbols' -delete

file_count=$(find "$OUT" -type f | wc -l | tr -d ' ')
total_kb=$(du -sk "$OUT" | cut -f1)

(cd "$OUT" && zip -qr "$ZIP" .)
zip_list=$(unzip -Z1 "$ZIP")
grep -qx 'index.html' <<<"$zip_list" || fail "index.html is not at the zip root"

echo "GamePix bundle: $OUT ($file_count files, ${total_kb}KB)"
echo "Upload zip: $ZIP ($(du -k "$ZIP" | cut -f1)KB)"
echo "crazygames strings in main.dart.js: $(grep -oi crazygames "$OUT/main.dart.js" | wc -l | tr -d ' ')"
