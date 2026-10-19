# Provisioning Flatcar hosts

How a Flatcar host gets the `tools` sysext and keeps it current. A full Butane
example is in [../examples/tools-sysext.bu](../examples/tools-sysext.bu).

## The tools sysext

At first boot, Ignition writes the seed image to
`/opt/extensions/tools/tools-0-<arch>.raw` from the unversioned asset that
tracks the latest release, links `/etc/extensions/tools.raw` to it so
systemd-sysext merges it, and installs the transfer config at
`/etc/sysupdate.tools.d/tools.transfer` and a no-op transfer at
`/etc/sysupdate.d/noop.transfer`. Version 0 makes the seed the oldest
instance, so sysupdate prunes it like any other.

After that, `systemd-sysext` merges the image into `/usr` on every boot and the
binaries (`emacs`, `nano`, `ncdu`, `htop`) are on `PATH`.

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

The `systemd-tmpfiles` step is only needed for an in-place merge; on a normal
boot it runs on its own. emacs ships a `tmpfiles.d` drop-in that creates the
directory Debian's emacs reads at startup.

The `noop.transfer` exists because the default, componentless
`systemd-sysupdate.service` invocation still runs; it gives that invocation a
transfer that matches nothing instead of erroring.

## Notes

- The transfer uses `Verify=false`: integrity comes from `SHA256SUMS`, but the
  index itself is not signed. dm-verity roothash signing can be layered on
  later if you want stricter guarantees.
- `InstancesMax=3` keeps the last three images under `/opt/extensions/tools`
  for rollback.
- To pin a host to a specific version, drop the sysupdate drop-in and manage
  `/etc/extensions/tools.raw` yourself.
- An unversioned `/opt/extensions/tools/tools-x86-64.raw` left by older
  configs is never pruned; delete it once `/etc/extensions/tools.raw` points
  elsewhere.
