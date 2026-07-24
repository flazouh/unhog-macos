#!/bin/zsh
set -euo pipefail

# Code-quality gate: lint, a from-scratch compile, and the full test suite.
# Run by CI on every push/PR and by scripts/release-app.sh before any build is
# signed. A clean build is used on purpose so a stale incremental cache can
# never hide a compile error that a fresh checkout (CI) would surface.

UNHOG_ROOT="${0:A:h:h}"
cd "$UNHOG_ROOT"

if ! command -v swift >/dev/null 2>&1; then
  print -u2 "swift toolchain not found on PATH."
  exit 1
fi

print "==> Lint (swift format)"
swift format lint \
  --strict \
  --recursive \
  --configuration .swift-format \
  Sources Tests

print "==> Clean build (all targets)"
rm -rf .build
swift build

print "==> Tests"
swift test

print "==> All quality checks passed."
