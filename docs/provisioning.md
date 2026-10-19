# Provisioning Flatcar hosts

How a Flatcar host gets the `tools` sysext and keeps it current. A full Butane
example is in [../examples/tools-sysext.bu](../examples/tools-sysext.bu).

## The tools sysext

At first boot, Ignition places three things:

- the initial image at `/opt/extensions/tools/tools-<arch>.raw` (the stable
  asset that tracks the latest release), with `/etc/extensions/tools.raw`
  symlinked to it so systemd-sysext merges it;
- the sysupdate transfer config at `/etc/sysupdate.tools.d/tools.transfer`;
- a no-op transfer at `/etc/sysupdate.d/noop.transfer`.

After that, `systemd-sysext` merges the image into `/usr` on every boot and the
binaries (`emacs`, `nano`, `ncdu`, `htop`) are on `PATH`.

## Updates

`systemd-sysupdate.timer` runs periodically. The drop-in on
`systemd-sysupdate.service` runs `systemd-sysupdate -C tools update`, which
reads `/etc/sysupdate.tools.d/tools.transfer`, fetches the `SHA256SUMS` index from
the rolling `tools` release, and downloads a newer image if one exists.

A downloaded image becomes active on the next boot. The drop-in touches
`/run/reboot-required` when the active image changed, so your reboot tooling
can pick it up. To merge immediately without a reboot:

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
