#!/bin/zsh
set -euo pipefail

UNHOG_ROOT="${0:A:h:h}"
UNHOG_BUILD="$UNHOG_ROOT/.build"
UNHOG_APP="$UNHOG_ROOT/dist/Unhog.app"
UNHOG_CONTENTS="$UNHOG_APP/Contents"
UNHOG_SIGN_IDENTITY="${UNHOG_SIGN_IDENTITY:--}"

env \
  CLANG_MODULE_CACHE_PATH="$UNHOG_BUILD/cache/clang" \
  SWIFTPM_MODULECACHE_OVERRIDE="$UNHOG_BUILD/cache/swiftpm" \
  XDG_CACHE_HOME="$UNHOG_BUILD/cache" \
  swift build \
    --package-path "$UNHOG_ROOT" \
    --configuration release \
    --disable-sandbox

if [[ -e "$UNHOG_APP" ]]; then
  rm -rf "$UNHOG_APP"
fi

install -d "$UNHOG_CONTENTS/MacOS"
install -d "$UNHOG_CONTENTS/Resources"
install -m 755 "$UNHOG_BUILD/release/Unhog" "$UNHOG_CONTENTS/MacOS/Unhog"
install -m 644 "$UNHOG_ROOT/Support/Info.plist" "$UNHOG_CONTENTS/Info.plist"
install -m 644 "$UNHOG_ROOT/Support/Unhog.icns" "$UNHOG_CONTENTS/Resources/Unhog.icns"
cp -R \
  "$UNHOG_BUILD/release/Unhog_Unhog.bundle" \
  "$UNHOG_CONTENTS/Resources/Unhog_Unhog.bundle"

if [[ "$UNHOG_SIGN_IDENTITY" == "-" ]]; then
  codesign --force --sign - "$UNHOG_APP"
else
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$UNHOG_SIGN_IDENTITY" \
    "$UNHOG_APP"
fi

print "Built $UNHOG_APP"
