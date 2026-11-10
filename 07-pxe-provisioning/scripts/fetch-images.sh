#!/usr/bin/env bash
# Download the prebuilt images from the GitHub release and check their
# checksums. Skips the hours-long Yocto build.
set -euo pipefail
# shellcheck source=lib.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

mkdir -p "$IMAGES_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp:?}"' EXIT

echo "downloading $RELEASE_TAG from $RELEASE_URL"
curl -fL --retry 3 -o "$tmp/SHA256SUMS" "$RELEASE_URL/SHA256SUMS"
for f in "${IMAGE_FILES[@]}"; do
	curl -fL --retry 3 -o "$tmp/$f" "$RELEASE_URL/$f"
done
(cd "$tmp" && sha256sum --check SHA256SUMS)
for f in "${IMAGE_FILES[@]}"; do
	mv "$tmp/$f" "$IMAGES_DIR/$f"
done
echo "images are in $IMAGES_DIR"
