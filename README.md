# flatcar-packages

Extra command-line tools for [Flatcar Container Linux][flatcar], shipped as a
[systemd-sysext][sysext] image. Flatcar's `/usr` is read-only and its base
image deliberately minimal, so extra tools ship as a sysext rather than
installed packages.

## What's in the `tools` sysext

- `emacs-nox`: text editor
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

`build/build.sh <arch> <version>` installs the Alpine packages in a container,
wraps the binaries with [flatwrap][flatwrap] so the musl-linked binaries run on
Flatcar's glibc userland, and packs the result into a squashfs sysext image.

```sh
build/build.sh x86-64 0.0.1
build/smoke.sh tools-0.0.1-x86-64.raw
```

## Updates

- The `release` workflow rebuilds weekly (Fridays) and on changes to `main`.
  It publishes a new rolling release only when the resolved Alpine package set
  actually changed.
- Dependabot bumps the GitHub Actions and the Alpine base image every Friday;
  non-major bumps auto-merge once CI is green.

## Adding a tool

Edit [extensions/tools/packages](extensions/tools/packages) (Alpine package
names) and, if it ships a binary you want on `PATH`,
[extensions/tools/binaries](extensions/tools/binaries) (absolute paths). Open a
PR; the build workflow validates it.

## License

Apache-2.0. `build/flatwrap.sh` is vendored from the Flatcar sysext-bakery; see
[NOTICE](NOTICE).

[flatcar]: https://www.flatcar.org/
[sysext]: https://www.flatcar.org/docs/latest/provisioning/sysext/
[flatwrap]: https://github.com/flatcar/sysext-bakery
[release]: https://github.com/tesserac-ai/flatcar-packages/releases/tag/tools
