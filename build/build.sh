#!/usr/bin/env bash
#
# Build the `tools` systemd-sysext image for Flatcar from Debian packages.
#
# Usage: build/build.sh <arch> <version>
#   <arch>     x86-64 | arm64
#   <version>  image version string; the release uses <date>.<run>, e.g. 2026.10.19.33
#
# Output, in the current directory:
#   tools-<version>-<arch>.raw   squashfs sysext image
#   MANIFEST-<arch>              packages installed in the build container
#   SOURCES-<arch>               source packages of the bundled files
#
# flix bundles each binary with its libraries and loader, so the merged tools
# run as plain host processes. The only build dependency is docker.

set -euo pipefail

here="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
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
  "$name" "$arch" "$version" "$packages" "$binaries" "$resources" <<'IN'
set -eu
name="$1" ; arch="$2" ; version="$3"
packages="$4" ; binaries="$5" ; resources="$6"

# Hand everything in the bind-mounted /out back to the host user on any exit,
# so the caller can clean up even when the build fails partway.
trap 'chown -R "$(stat -c "%u:%g" /out)" /out 2>/dev/null || true' EXIT

export DEBIAN_FRONTEND=noninteractive
apt-get update >/dev/null
apt-get install -y --no-install-recommends $packages patchelf squashfs-tools >/dev/null

# Everything installed in the build container.
dpkg-query -W -f='${Package} ${Version}\n' | sort > "/out/MANIFEST-$arch"

cd /out

# Drop the friendly-name suffix (path=name) before handing paths to flix.
flixpaths=""
for b in $binaries; do flixpaths="$flixpaths ${b%%=*}"; done

/flix.sh / "$name" $flixpaths $resources

# Debian ships e.g. /usr/bin/emacs as an alternatives symlink, which flix can't
# wrap; expose the friendly name as a relative symlink to the real binary.
for b in $binaries; do
  case "$b" in
  *=*) ln -sf "$(basename "${b%%=*}")" "$name/usr/bin/${b##*=}" ;;
  esac
done

# Ship the copyright file of every package a bundled file came from, plus the
# /usr/share/common-licenses they refer to. flix copies libraries into
# usr/local under their soname, so those are matched by name. A file no
# package owns fails the build.
awk '{ p = FILENAME; sub(".*/", "", p); sub("[.]list$", "", p); sub(":.*", "", p); print $0 "\t" p }' \
  /var/lib/dpkg/info/*.list > /tmp/owners
find "$name/usr" -type f | sed "s|^$name||" > /tmp/files
: > /tmp/unowned
awk -F '\t' '
  NR == FNR { own[$1] = own[$1] " " $2; n = $1; sub(".*/", "", n); if ($1 ~ /^\/(usr\/)?lib/) lib[n] = lib[n] " " $2; next }
  { n = $0; sub(".*/", "", n); k = /^\/usr\/local\// ? lib[n] : own[$0] }
  k == "" { print > "/tmp/unowned"; next }
  { m = split(k, a, " "); for (i = 1; i <= m; i++) print a[i] }
' /tmp/owners /tmp/files > /tmp/pkgs
# emacsen-common byte-compiles lisp at install time, next to a symlink to the
# packaged .el. Credit the .elc to whoever owns that .el.
while read -r f; do
  p=
  case "$f" in
  *.elc) p="$(awk -F '\t' -v f="$(realpath -m "${f%c}")" '$1 == f { print $2 }' /tmp/owners)" ;;
  esac
  [ -n "$p" ] || { echo "no package owns $f" >&2 ; exit 1 ; }
  echo "$p" >> /tmp/pkgs
done < /tmp/unowned
pkgs="$(sort -u /tmp/pkgs)"
for p in $pkgs; do
  mkdir -p "$name/usr/share/doc/$p"
  cp -L "/usr/share/doc/$p/copyright" "$name/usr/share/doc/$p/"
done
cp -a /usr/share/common-licenses "$name/usr/share/"

# Source packages behind the bundled files, for the release's source archive.
dpkg-query -W -f='${source:Package} ${source:Version}\n' $pkgs | sort -u > "/out/SOURCES-$arch"

# Overlay, then append the package list to its NOTICE.
cp -a /overlay/. "$name/"
dpkg-query -W -f='${Package} ${source:Package} ${source:Version}\n' $pkgs \
  >> "$name/usr/share/doc/flatcar-tools/NOTICE"

# ID=_any: the image carries its own loader and libraries. ARCHITECTURE still
# has to match the host.
meta="$name/usr/lib/extension-release.d/extension-release.$name"
mkdir -p "$(dirname "$meta")"
printf 'ID=_any\nARCHITECTURE=%s\n' "$arch" > "$meta"

# This merges into the host /usr: no 0700 dirs, no setuid or sticky bits,
# nothing group- or world-writable.
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
mv "$work/MANIFEST-$arch" "$work/SOURCES-$arch" .
echo "built $name-$version-$arch.raw"
