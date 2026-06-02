#!/usr/bin/env bash
#
# Build the `tools` systemd-sysext image for Flatcar from Debian packages.
#
# Usage: build/build.sh <arch> <version>
#   <arch>     x86-64 | arm64
#   <version>  image version string, e.g. 2026.06.02
#
# Output, in the current directory:
#   tools-<version>-<arch>.raw   squashfs sysext image
#   MANIFEST-<arch>              resolved package versions, for change detection
#
# Debian's glibc binaries run on Flatcar's glibc userland. flix bundles each
# binary with its libraries and dynamic loader, so the merged tools run as
# ordinary host processes with the full host filesystem, host /etc and host
# identity. The only host dependency is docker.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(dirname "$here")"
name=tools

arch="${1:?usage: build.sh <arch> <version>}"
version="${2:?usage: build.sh <arch> <version>}"

case "$arch" in
x86-64)
  platform=linux/amd64
  multiarch=x86_64-linux-gnu
  ;;
arm64)
  platform=linux/arm64/v8
  multiarch=aarch64-linux-gnu
  ;;
*)
  echo "unknown arch '$arch' (want x86-64 or arm64)" >&2
  exit 1
  ;;
esac

base="$(awk '/^FROM/ {print $2; exit}' "$here/Dockerfile")"

strip() { grep -vE '^[[:space:]]*(#|$)' "$1"; }
ext="$repo/extensions/$name"
packages="$(strip "$ext/packages" | tr '\n' ' ')"
binaries="$(strip "$ext/binaries" | tr '\n' ' ')"
resources="$(strip "$ext/resources" | tr '\n' ' ')"

work="$(mktemp -d)"
trap 'chmod -R u+w "$work" 2>/dev/null || true ; rm -rf "$work"' EXIT

docker run --rm -i \
  --platform "$platform" \
  --pull always \
  --network host \
  -v "$here/flix.sh:/flix.sh:ro" \
  -v "$ext/overlay:/overlay:ro" \
  -v "$work:/out" \
  "$base" sh -s -- \
  "$name" "$arch" "$version" "$multiarch" "$packages" "$binaries" "$resources" <<'IN'
set -eu
name="$1" ; arch="$2" ; version="$3" ; multiarch="$4"
packages="$5" ; binaries="$6" ; resources="$7"

# Hand everything in the bind-mounted /out back to the host user on any exit,
# so the caller can clean up even when the build fails partway.
trap 'chown -R "$(stat -c "%u:%g" /out)" /out 2>/dev/null || true' EXIT

export DEBIAN_FRONTEND=noninteractive
apt-get update >/dev/null
apt-get install -y --no-install-recommends $packages patchelf squashfs-tools >/dev/null

# All resolved package versions (incl. dependencies), for the release gate.
dpkg-query -W -f='${Package} ${Version}\n' | sort > "/out/MANIFEST-$arch"

cd /out

# Drop the friendly-name suffix (path=name) before handing paths to flix.
flixpaths=""
for b in $binaries; do flixpaths="$flixpaths ${b%%=*}"; done

# Bundle each binary with its libraries and loader.
/flix.sh / "$name" $flixpaths $resources

# The NSS plugins are dlopen'd at runtime, so they are never reported as needed
# libraries. Drop them where flix already points the rpath (extralibs/), or
# host name and user lookups fail. flix's own EXTRALIBS path can't create the
# directory, so do it by hand.
nss="/lib/$multiarch"
mkdir -p "$name/usr/local/$name/extralibs"
cp -a "$nss/libnss_files.so.2" "$nss/libnss_dns.so.2" "$name/usr/local/$name/extralibs/"

# Debian ships e.g. /usr/bin/emacs as an alternatives symlink, which flix can't
# wrap; expose the friendly name as a relative symlink to the real binary.
for b in $binaries; do
  case "$b" in
  *=*) ln -sf "$(basename "${b%%=*}")" "$name/usr/bin/${b##*=}" ;;
  esac
done

# Static overlay: tmpfiles and the like.
cp -a /overlay/. "$name/"

# extension-release: flix bundles the loader and libraries, so the image is
# self-contained and loads on any OS (ID=_any); ARCHITECTURE must match.
meta="$name/usr/lib/extension-release.d/extension-release.$name"
mkdir -p "$(dirname "$meta")"
printf 'ID=_any\nARCHITECTURE=%s\n' "$arch" > "$meta"

# Keep the merged /usr world-traversable (apt and flix leave a few 0700 paths)
# and drop setuid/setgid/sticky and group/other-write: this tree merges into
# the host /usr, so it must not introduce a writable or setuid path.
chmod -R a+rX "$name"
chmod -R a-st,go-w "$name"

# Pack into a reproducible squashfs.
img="/out/$name-$version-$arch.raw"
rm -f "$img"
export SOURCE_DATE_EPOCH=0
set -- -all-root -noappend
sqver="$(mksquashfs -version | head -n1 | cut -d' ' -f3)"
if [ "$(printf '%s\n4.6.1\n' "$sqver" | sort -V | tail -n1)" = "$sqver" ]; then
  set -- "$@" -xattrs-exclude '^btrfs.' # reproducibility: drop btrfs xattrs
fi
mksquashfs "/out/$name" "$img" "$@" >/dev/null
IN

mv "$work/$name-$version-$arch.raw" .
mv "$work/MANIFEST-$arch" "MANIFEST-$arch"
echo "built $name-$version-$arch.raw"
