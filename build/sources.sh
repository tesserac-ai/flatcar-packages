#!/usr/bin/env bash
#
# Fetch the Debian source packages a build bundled into one tar, so the release
# carries the corresponding source next to the image.
#
# Usage: build/sources.sh <SOURCES-arch> <out.tar>
#   Both paths relative to the current directory, as build/build.sh leaves them.

set -euo pipefail

list="${1:?usage: sources.sh <SOURCES-arch> <out.tar>}"
out="${2:?usage: sources.sh <SOURCES-arch> <out.tar>}"
here="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
base="$(awk '/^FROM/ {print $2; exit}' "$here/Dockerfile")"

docker run --rm -i --pull always -v "$PWD:/w" -w /w "$base" sh -s -- "$list" "$out" <<'IN'
set -eu
list="$1" ; out="$2"
trap 'chown "$(stat -c "%u:%g" /w)" "/w/$out" 2>/dev/null || true' EXIT

# The base image lists binary suites only; the same suites carry the sources.
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources
apt-get update >/dev/null

mkdir /src
chown _apt /src # apt drops to _apt for downloads
cd /src
while read -r pkg ver; do
  # --only-source: the list holds source names; without it apt also matches
  # binary names and version prefixes.
  apt-get source --only-source --download-only "$pkg=$ver" >/dev/null
done < "/w/$list"
tar -cf "/w/$out" .
IN
echo "fetched sources into $out"
