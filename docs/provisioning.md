# Provisioning Flatcar hosts

How a Flatcar host gets the `tools` sysext and keeps it current. A full Butane
example is in [../examples/tools-sysext.bu](../examples/tools-sysext.bu).

## The tools sysext

At first boot, Ignition writes the seed image to
`/opt/extensions/tools/tools-0-<arch>.raw` from the unversioned asset that
tracks the latest release, links `/etc/extensions/tools.raw` to it so
systemd-sysext merges it, and installs the transfer config at
`/etc/sysupdate.tools.d/tools.transfer`. Version 0 makes the seed the oldest
instance, so sysupdate prunes it like any other.

After that, `systemd-sysext` merges the image into `/usr` on every boot and the
tools are on `PATH`.

## Updates

`systemd-sysupdate.timer` runs periodically. The drop-in on
`systemd-sysupdate.service` runs `systemd-sysupdate -C tools update`, which
reads `/etc/sysupdate.tools.d/tools.transfer`, fetches the `SHA256SUMS` index from
the rolling `tools` release, and downloads a newer image if one exists.

A downloaded image becomes active on the next boot. The drop-in touches
`/run/reboot-required` when the update moves `/etc/extensions/tools.raw` to
different bytes, so your reboot tooling can pick it up. It compares content,
not paths, because the first update on a new host usually re-fetches the
seed's bytes under a real version. To merge immediately without a reboot:

```sh
systemd-sysupdate -C tools update
systemd-sysext refresh
systemd-tmpfiles --create # emacs needs /etc/emacs/site-start.d
```

Flatcar 4459.2.3 and LTS 4081.3.7 onwards ship a no-op transfer for the
default, componentless sysupdate run. On older images, install the release's
`noop.transfer` as `/etc/sysupdate.d/noop.transfer` (`noop.conf` on LTS), or
that run fails and the unit shows as failed; the tools update either way.

## Notes

- The transfer uses `Verify=false`: integrity comes from `SHA256SUMS`, but the
  index itself is not signed. Publishing a signed `SHA256SUMS.gpg` and setting
  `Verify=yes` would fix that.
- `.transfer` files need systemd 257 or newer, which stable, beta and alpha
  have. LTS (systemd 255) only reads `.conf`; install the file as
  `/etc/sysupdate.tools.d/tools.conf` there.
- `InstancesMax=3` keeps the last three images under `/opt/extensions/tools`
  for rollback.
- To pin a host to a specific version, remove the
  `systemd-sysupdate.service.d/tools.conf` drop-in and manage
  `/etc/extensions/tools.raw` yourself.
- An unversioned `/opt/extensions/tools/tools-x86-64.raw` left by older
  configs is never pruned; delete it once `/etc/extensions/tools.raw` points
  elsewhere.
