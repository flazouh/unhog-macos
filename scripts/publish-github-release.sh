#!/bin/zsh
set -euo pipefail

UNHOG_ROOT="${0:A:h:h}"
UNHOG_REPOSITORY="flazouh/unhog-macos"

if [[ "${1:-}" == "--print-config" ]]; then
  print "GitHub repository: $UNHOG_REPOSITORY"
  exit 0
fi

if (( $# > 0 )); then
  print -u2 "Usage: ./scripts/publish-github-release.sh"
  exit 2
fi

working_tree_status="$(git -C "$UNHOG_ROOT" status --porcelain)"
if [[ -n "$working_tree_status" ]]; then
  print -u2 "Refusing to publish from a dirty Git working tree."
  exit 1
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$UNHOG_ROOT/Support/Info.plist")"
tag="v$version"
dmg="$UNHOG_ROOT/dist/Unhog-$version.dmg"
checksum="$dmg.sha256"
build_commit_file="$dmg.commit"

if [[ ! -f "$dmg" || ! -f "$checksum" || ! -f "$build_commit_file" ]]; then
  print -u2 "Missing notarized release files. Run ./scripts/release-app.sh first."
  exit 1
fi

(cd "$UNHOG_ROOT/dist" && shasum -a 256 -c "${checksum:t}")
xcrun stapler validate "$dmg"
spctl \
  --assess \
  --verbose=2 \
  --type open \
  --context context:primary-signature \
  "$dmg"

local_head="$(git -C "$UNHOG_ROOT" rev-parse HEAD)"
build_commit="$(< "$build_commit_file")"
if [[ "$build_commit" != "$local_head" ]]; then
  print -u2 "The DMG was not built from the current Git commit."
  print -u2 "Rebuild the release before publishing."
  exit 1
fi

remote_head="$(git -C "$UNHOG_ROOT" ls-remote origin refs/heads/main | awk '{print $1}')"
if [[ "$local_head" != "$remote_head" ]]; then
  print -u2 "Local HEAD is not the commit currently pushed to origin/main."
  print -u2 "Push the release commit before publishing."
  exit 1
fi

gh release create "$tag" \
  "$dmg" \
  "$checksum" \
  "$build_commit_file" \
  --repo "$UNHOG_REPOSITORY" \
  --target "$local_head" \
  --title "Unhog $version" \
  --generate-notes \
  --latest

print
print "Published https://github.com/$UNHOG_REPOSITORY/releases/tag/$tag"
