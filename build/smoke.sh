#!/usr/bin/env bash
#
# Verify a built sysext image: the expected entry points and metadata exist.
#
# Usage: build/smoke.sh <image.raw>

set -euo pipefail

img="${1:?usage: smoke.sh <image.raw>}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base="$(awk '/^FROM/ {print $2; exit}' "$here/Dockerfile")"

docker run --rm -i -v "$PWD:/w" -w /w "$base" sh -s -- "$img" <<'IN'
set -eu
img="$1"
apk add -U squashfs-tools >/dev/null
for b in emacs nano ncdu htop; do
  unsquashfs -l "$img" | grep -q "usr/bin/$b$" || { echo "missing /usr/bin/$b" >&2 ; exit 1 ; }
done
unsquashfs -l "$img" | grep -q "extension-release.tools$" \
  || { echo "missing extension-release.tools" >&2 ; exit 1 ; }
echo "smoke ok: $img"
IN
