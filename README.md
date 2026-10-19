# flatcar-packages

Extra command-line tools for [Flatcar Container Linux][flatcar], shipped as a
[systemd-sysext][sysext] image, since Flatcar's `/usr` is read-only and has no
package manager.

## What's in the `tools` sysext

- `emacs-nox`: text editor
- `nano`: small editor
- `ncdu`: disk usage browser
- `htop`: process viewer

## How hosts consume it

Ignition provisions the sysext at first boot and `systemd-sysupdate` keeps it
current; see [examples/tools-sysext.bu](examples/tools-sysext.bu) and
[docs/provisioning.md](docs/provisioning.md). Hosts pull images straight from
the rolling [`tools`][release] release.

## How it's built

`build/build.sh <arch> <version>` installs the Debian packages in a container
and bundles each binary with its libraries and loader using [flix][flix], so
the merged tools run as plain host processes. The result is a squashfs sysext
image.

```sh
build/build.sh x86-64 0.0.1
build/smoke.sh tools-0.0.1-x86-64.raw
```

## Updates

- The `release` workflow rebuilds weekly (Fridays) and on changes to `main`.
  Images build reproducibly, so it publishes a new rolling release only when
  an image hash changed; transfer edits are uploaded to the current release.
- Dependabot bumps the GitHub Actions and the Debian base image every Friday;
  non-major bumps auto-merge once the `build` check passes.

## Adding a tool

Add the Debian package to [extensions/tools/packages](extensions/tools/packages),
the binary to put on `PATH` to
[extensions/tools/binaries](extensions/tools/binaries), and any runtime data it
needs to [extensions/tools/resources](extensions/tools/resources). List it in
`build/smoke.sh` too. Open a PR; CI builds and smoke-tests it.

## License

The scripts and configs in this repo are Apache-2.0. `build/flix.sh` is
vendored from the Flatcar sysext-bakery; see [NOTICE](NOTICE).

The images bundle Debian packages as dpkg installed them, except that patchelf
rewrote the ELF interpreter and library search path at build time. Each
package keeps its own license. `/usr/share/doc/flatcar-tools/NOTICE` in the
image lists them; each release carries their source as
`tools-<version>-source.tar`, and its tag marks the commit the image was built
from.

[flatcar]: https://www.flatcar.org/
[sysext]: https://www.flatcar.org/docs/latest/provisioning/sysext/
[flix]: https://github.com/flatcar/sysext-bakery
[release]: https://github.com/tesserac-ai/flatcar-packages/releases/tag/tools
