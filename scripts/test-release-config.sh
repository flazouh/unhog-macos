#!/bin/zsh
set -euo pipefail

UNHOG_ROOT="${0:A:h:h}"
UNHOG_RELEASE_SCRIPT="$UNHOG_ROOT/scripts/release-app.sh"
UNHOG_PUBLISH_SCRIPT="$UNHOG_ROOT/scripts/publish-github-release.sh"

config="$("$UNHOG_RELEASE_SCRIPT" --print-config)"
publish_config="$("$UNHOG_PUBLISH_SCRIPT" --print-config)"

if [[ "$config" != *"Developer ID Application: Alexandre de Pape (GD7PWQBWJV)"* ]]; then
  print -u2 "Release identity is not the Alexandre de Pape Developer ID certificate."
  exit 1
fi

if [[ "$config" != *"Expected team: GD7PWQBWJV"* ]]; then
  print -u2 "Release team is not locked to GD7PWQBWJV."
  exit 1
fi

if [[ "$config" != *"Notary profile: unhog-notary-alexandre"* ]]; then
  print -u2 "Notarization is not locked to the Alexandre Keychain profile."
  exit 1
fi

if [[ "$config" == *"Ryan Roberts"* ]]; then
  print -u2 "Release configuration must never select the Ryan Roberts account."
  exit 1
fi

if [[ "$publish_config" != *"GitHub repository: flazouh/unhog-macos"* ]]; then
  print -u2 "Release downloads are not locked to the public Unhog repository."
  exit 1
fi

print "Release configuration contract passed."
