#!/usr/bin/env bash
# Add a <release> entry for $VERSION to the appdata file, built from the upstream
# release notes. No-op if that version is already listed.
#
# Usage: update_changelog.sh <version> <base-url>
set -euo pipefail

VERSION="$1"
BASE_URL="$2"
APPDATA="io.trezor.suite.appdata.xml"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if grep -q "<release version=\"$VERSION\"" "$APPDATA"; then
  echo "Release $VERSION is already in $APPDATA, nothing to do."
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL "$BASE_URL/v$VERSION/latest-linux.yml" -o "$work/latest-linux.yml"
date="$(yq -r '.releaseDate' "$work/latest-linux.yml" | cut -c1-10)"

# The product-update article is named after the release month, e.g. 26.6.1 -> June 2026:
# https://trezor.io/.../trezor-suite-update-june-2026
months=(_ january february march april may june july august september october november december)
year_short="${VERSION%%.*}"          # 26.6.1 -> 26
month_num="${VERSION#*.}"; month_num="${month_num%%.*}"   # 26.6.1 -> 6
details_url="https://trezor.io/other/product-updates/trezor-suite-updates/trezor-suite-update-${months[month_num]}-20${year_short}"

# Strip emoji from the markdown notes: the pictograph characters themselves, plus
# the variation-selector / zero-width-joiner / keycap codepoints that glue
# multi-codepoint emoji together. Upstream headings look like "### <emoji> New features",
# so removing the emoji leaves a double space; collapse runs of spaces and trim line ends.
strip_emoji() {
  perl -CSD -pe '
    s/\p{Extended_Pictographic}//g;
    s/[\x{FE00}-\x{FE0F}\x{200D}\x{20E3}]//g;
    s/ {2,}/ /g;
    s/ +$//;
  '
}

# Turn the markdown notes into a <release> block in this file's house style.
yq -r '.releaseNotes' "$work/latest-linux.yml" | strip_emoji \
  | python3 "$HERE/render_release.py" "$VERSION" "$date" "$details_url" > "$work/block.xml"
[ -s "$work/block.xml" ] || { echo "Got no release notes to insert" >&2; exit 1; }
cp "$work/block.xml" "$RUNNER_TEMP/block.xml"

# Insert the new entry directly after <releases> so the newest release is first.
awk -v block="$work/block.xml" '
  /<releases>/ && !inserted {
    print
    while ((getline line < block) > 0) print line
    inserted = 1
    next
  }
  { print }
' "$APPDATA" > "$APPDATA.tmp"
mv "$APPDATA.tmp" "$APPDATA"

echo "Added release $VERSION ($date) to $APPDATA."
