#!/usr/bin/env bash
# Point the Flatpak manifest at a new Trezor Suite release: download each AppImage,
# then rewrite its url / size / sha256 in the manifest.
#
# Usage: update_manifest.sh <version> <base-url>
set -euo pipefail

VERSION="$1"
BASE_URL="$2"
MANIFEST="io.trezor.suite.yml"
RELEASE_URL="$BASE_URL/v$VERSION"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Point the manifest's extra-data block for one arch at a freshly downloaded AppImage.
# $arch is the manifest's only-arches value (x86_64 / aarch64); $file is the AppImage name.
update_arch() {
  local arch="$1" file="$2"
  local url="$RELEASE_URL/$file"

  echo "Downloading $url"
  curl -fL -o "$work/$file" "$url"
  local size sha
  size="$(stat -c%s "$work/$file")"
  sha="$(sha256sum "$work/$file" | awk '{print $1}')"
  echo "  size=$size sha256=$sha"

  # The block looks like:
  #   only-arches: [x86_64]
  #   url: ...
  #   size: ...
  #   sha256: ...
  # Match from the arch marker up to its sha256 and rewrite the three values.
  # -z so the regex can span the newlines between the fields.
  sed -i -z "s|only-arches: \[$arch\][^-]*url: [^\n]*Trezor-Suite-[^\n]*.AppImage[^s]*size: [0-9]*[^s]*sha256: [a-f0-9]*|only-arches: [$arch]\n        url: $url\n        size: $size\n        sha256: $sha|" "$MANIFEST"
}

update_arch x86_64  "Trezor-Suite-$VERSION-linux-x86_64.AppImage"
update_arch aarch64 "Trezor-Suite-$VERSION-linux-arm64.AppImage"

echo "Updated $MANIFEST to $VERSION."
