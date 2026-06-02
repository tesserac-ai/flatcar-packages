#!/usr/bin/env bash
#
# Build the `tools` systemd-sysext image for Flatcar from Alpine packages.
#
# Usage: build/build.sh <arch> <version>
#   <arch>     x86-64 | arm64
#   <version>  image version string, e.g. 2026.06.02
#
# Output, in the current directory:
#   tools-<version>-<arch>.raw   squashfs sysext image
#   MANIFEST-<arch>              resolved package versions, for change detection
#
# The only host dependency is docker. The Alpine binaries are musl-linked, so
# flatwrap wraps them in a self-contained chroot that runs on Flatcar's glibc
# userland.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(dirname "$here")"
name=tools

arch="${1:?usage: build.sh <arch> <version>}"
version="${2:?usage: build.sh <arch> <version>}"

case "$arch" in
x86-64) platform=linux/amd64 ;;
arm64) platform=linux/arm64/v8 ;;
*)
  echo "unknown arch '$arch' (want x86-64 or arm64)" >&2
  exit 1
  ;;
esac

base="$(awk '/^FROM/ {print $2; exit}' "$here/Dockerfile")"

strip() { grep -vE '^[[:space:]]*(#|$)' "$1"; }
packages="$(strip "$repo/extensions/$name/packages" | tr '\n' ' ')"
binaries="$(strip "$repo/extensions/$name/binaries" | tr '\n' ' ')"

work="$(mktemp -d)"
trap 'chmod -R u+w "$work" 2>/dev/null || true ; rm -rf "$work"' EXIT
root="$work/root"
mkdir -p "$root"

docker run --rm -i \
  --platform "$platform" \
  --pull always \
  --network host \
  -v "$here/flatwrap.sh:/flatwrap.sh:ro" \
  -v "$work:/out" \
  "$base" sh -s -- "$name" "$arch" "$packages" "$binaries" <<'IN'
set -eu
name="$1" ; arch="$2" ; packages="$3" ; binaries="$4"
apk add -U $packages bash coreutils grep >/dev/null
apk info -v | sort > "/out/MANIFEST-$arch"
cd /out/root

# flatwrap won't wrap a symlinked entry point; wrap the real target and
# relink the friendly name to it.
wrap="" ; links=""
for b in $binaries; do
  if [ -L "$b" ]; then
    real="$(realpath "$b")"
    wrap="$wrap $real"
    links="$links ${b##*/}:${real##*/}"
  else
    wrap="$wrap $b"
  fi
done

# Alpine keeps terminfo under /etc, so keep the chroot's /etc (ETCMAP=chroot).
ETCMAP=chroot /flatwrap.sh / "$name" $wrap

for l in $links; do
  ln -sf "${l##*:}" "$name/usr/bin/${l%%:*}"
done

chown -R "$(stat -c '%u:%g' /out)" /out
IN

# flatwrap emits <root>/<name>/usr; a sysext wants it at <root>/usr.
mv "$root/$name/usr" "$root/usr"
rmdir "$root/$name"
chmod -R u+w "$root"

# systemd-sysext metadata. ID=_any loads on any distro; ARCHITECTURE must match
# the host. SYSEXT_LEVEL is omitted for _any, systemd rejects it otherwise.
meta="$root/usr/lib/extension-release.d/extension-release.$name"
mkdir -p "$(dirname "$meta")"
printf 'ID=_any\nARCHITECTURE=%s\n' "$arch" >"$meta"

# Pack the tree into a reproducible squashfs image. Runs natively (squashfs is
# arch-independent) so the host needs no squashfs-tools.
docker run --rm -i \
  --network host \
  -v "$work:/out" \
  "$base" sh -s -- "$name" "$arch" "$version" <<'IN'
set -eu
name="$1" ; arch="$2" ; version="$3"
apk add -U squashfs-tools >/dev/null
img="/out/$name-$version-$arch.raw"
rm -f "$img"
export SOURCE_DATE_EPOCH=0
set -- -all-root -noappend
sqver="$(mksquashfs -version | head -n1 | cut -d' ' -f3)"
if [ "$(printf '%s\n4.6.1\n' "$sqver" | sort -V | tail -n1)" = "$sqver" ]; then
  set -- "$@" -xattrs-exclude '^btrfs.' # reproducibility: drop btrfs xattrs
fi
mksquashfs /out/root "$img" "$@" >/dev/null
chown "$(stat -c '%u:%g' /out)" "$img"
IN

mv "$work/$name-$version-$arch.raw" .
mv "$work/MANIFEST-$arch" "MANIFEST-$arch"
echo "built $name-$version-$arch.raw"
