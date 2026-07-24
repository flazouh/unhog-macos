#!/bin/zsh
set -euo pipefail

REPO_ROOT="${0:A:h:h}"
failures=0

if [[ "${REPO_ROOT:t}" != "Unhog" ]]; then
  print -u2 "Repository folder must be named Unhog, found ${REPO_ROOT:t}"
  failures=$((failures + 1))
fi

expect_text() {
  local file="$1"
  local expected="$2"

  if ! rg --fixed-strings --quiet "$expected" "$file"; then
    print -u2 "Missing '$expected' in ${file#$REPO_ROOT/}"
    failures=$((failures + 1))
  fi
}

expect_path() {
  local path="$1"

  if [[ ! -e "$path" ]]; then
    print -u2 "Missing ${path#$REPO_ROOT/}"
    failures=$((failures + 1))
  fi
}

expect_path "$REPO_ROOT/Sources/Unhog"
expect_path "$REPO_ROOT/Sources/UnhogCore"
expect_path "$REPO_ROOT/Tests/UnhogCoreTests"

expect_text "$REPO_ROOT/Package.swift" 'name: "Unhog"'
expect_text "$REPO_ROOT/Package.swift" '.executable(name: "Unhog"'
expect_text "$REPO_ROOT/Package.swift" '.library(name: "UnhogCore"'
expect_text "$REPO_ROOT/Support/Info.plist" '<string>Unhog</string>'
expect_text "$REPO_ROOT/Support/Info.plist" '<string>com.alex.unhog</string>'
expect_text "$REPO_ROOT/scripts/package-app.sh" 'dist/Unhog.app'

old_title="Cul""prit"
old_lower="cul""prit"
old_upper="CUL""PRIT"
if matches="$(
  rg -n "$old_title|$old_lower|$old_upper" "$REPO_ROOT" \
    --glob '!/.build/**' \
    --glob '!/dist/**' \
    --glob '!/.git/**' \
    --glob '!/scripts/verify-unhog-brand.sh' \
    || true
)"; [[ -n "$matches" ]]; then
  print -u2 "Old app identity remains:"
  print -u2 "$matches"
  failures=$((failures + 1))
fi

if (( failures > 0 )); then
  print -u2 "Unhog brand verification failed with $failures issue(s)."
  exit 1
fi

print "Unhog brand verification passed."
