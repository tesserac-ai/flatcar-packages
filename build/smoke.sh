#!/usr/bin/env bash
#
# Verify a built sysext image: the expected tools exist and actually run.
#
# Usage: build/smoke.sh <image.raw>

set -euo pipefail

img="${1:?usage: smoke.sh <image.raw>}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base="$(awk '/^FROM/ {print $2; exit}' "$here/Dockerfile")"

docker run --rm -i --privileged -v "$PWD:/w" -w /w "$base" sh -s -- "$img" <<'IN'
set -eu
img="$1"
export DEBIAN_FRONTEND=noninteractive
apt-get update >/dev/null
apt-get install -y --no-install-recommends squashfs-tools bubblewrap >/dev/null

root="$(mktemp -d)"
unsquashfs -q -d "$root/x" "$img" >/dev/null

[ -e "$root/x/usr/lib/extension-release.d/extension-release.tools" ] \
  || { echo "missing extension-release.tools" >&2 ; exit 1 ; }

# emacs reads this at launch (see overlay tmpfiles); systemd-tmpfiles makes it
# on the real host. Mimic that here so the bundled emacs starts.
mkdir -p /etc/emacs/site-start.d

# Run each tool with the sysext's /usr bound at /, as on a merged host.
run() {
  bwrap --ro-bind "$root/x/usr" /usr --ro-bind /etc /etc \
    --proc /proc --dev /dev --tmpfs /tmp --setenv HOME /tmp "$@"
}

for b in emacs nano htop ncdu; do
  [ -e "$root/x/usr/bin/$b" ] || { echo "missing /usr/bin/$b" >&2 ; exit 1 ; }
done

run /usr/bin/nano --version | head -1
run /usr/bin/htop --version | head -1
run /usr/bin/ncdu --version | head -1
run /usr/bin/emacs --batch --eval '(princ (concat "emacs " emacs-version))'
echo
echo "smoke ok: $img"
IN
