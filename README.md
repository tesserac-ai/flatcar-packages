# flatcar-packages

Extra command-line tools for [Flatcar Container Linux][flatcar], shipped as a
[systemd-sysext][sysext] image. Flatcar's `/usr` is read-only and its base
image deliberately minimal, so extra tools ship as a sysext rather than
installed packages.

## What's in the `tools` sysext

- `emacs-nox`: text editor
- `nano`: small editor
- `ncdu`: disk usage browser
- `htop`: process viewer

## How hosts consume it

Provision the sysext at first boot with Ignition and keep it current with
`systemd-sysupdate`. A worked example is in
[examples/tools-sysext.bu](examples/tools-sysext.bu); the mechanics are
explained in [docs/provisioning.md](docs/provisioning.md).

Released images live on the rolling [`tools`][release] GitHub release; hosts
pull from there directly.

## How it's built

`build/build.sh <arch> <version>` installs the Debian packages in a container
and bundles each binary with its libraries and dynamic loader using
[flix][flix]. Debian's glibc binaries run on Flatcar's glibc userland, so once
the sysext is merged the tools run as ordinary host processes — full host
filesystem, host `/etc`, host identity. The result is packed into a squashfs
sysext image.

```sh
build/build.sh x86-64 0.0.1
build/smoke.sh tools-0.0.1-x86-64.raw
```

## Updates

- The `release` workflow rebuilds weekly (Fridays) and on changes to `main`.
  Images build reproducibly, so it publishes a new rolling release only when
  an image hash changed; transfer edits are uploaded to the current release.
- Dependabot bumps the GitHub Actions on Fridays after a week's cooldown;
  non-major bumps auto-merge when `build` passes.
- The Debian tag in `build/Dockerfile` only moves on a new major, which needs a
  manual merge. Point and security updates need no bump: every build pulls the
  tag and upgrades its packages.

## Adding a tool

Edit [extensions/tools/packages](extensions/tools/packages) (Debian package
names). Put the binary you want on `PATH` in
[extensions/tools/binaries](extensions/tools/binaries) (absolute path, or
`path=name` to rename it), and any runtime data it needs (lisp, dumps) in
[extensions/tools/resources](extensions/tools/resources). Open a PR; the build
workflow validates it.

## License

Apache-2.0. `build/flix.sh` is vendored from the Flatcar sysext-bakery; see
[NOTICE](NOTICE).

[flatcar]: https://www.flatcar.org/
[sysext]: https://www.flatcar.org/docs/latest/provisioning/sysext/
[flix]: https://github.com/flatcar/sysext-bakery
[release]: https://github.com/tesserac-ai/flatcar-packages/releases/tag/tools
