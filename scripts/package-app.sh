#!/bin/zsh
set -euo pipefail

CULPRIT_ROOT="${0:A:h:h}"
CULPRIT_BUILD="$CULPRIT_ROOT/.build"
CULPRIT_APP="$CULPRIT_ROOT/dist/Culprit.app"
CULPRIT_CONTENTS="$CULPRIT_APP/Contents"

env \
  CLANG_MODULE_CACHE_PATH="$CULPRIT_BUILD/cache/clang" \
  SWIFTPM_MODULECACHE_OVERRIDE="$CULPRIT_BUILD/cache/swiftpm" \
  XDG_CACHE_HOME="$CULPRIT_BUILD/cache" \
  swift build \
    --package-path "$CULPRIT_ROOT" \
    --configuration release \
    --disable-sandbox

if [[ -e "$CULPRIT_APP" ]]; then
  rm -rf "$CULPRIT_APP"
fi

install -d "$CULPRIT_CONTENTS/MacOS"
install -d "$CULPRIT_CONTENTS/Resources"
install -m 755 "$CULPRIT_BUILD/release/Culprit" "$CULPRIT_CONTENTS/MacOS/Culprit"
install -m 644 "$CULPRIT_ROOT/Support/Info.plist" "$CULPRIT_CONTENTS/Info.plist"

codesign --force --sign - "$CULPRIT_APP"

print "Built $CULPRIT_APP"
