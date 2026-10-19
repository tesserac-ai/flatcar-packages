# flatcar-packages

Builds systemd-sysext images of extra CLI tools for Flatcar Container Linux.
The `tools` sysext (see `extensions/tools/packages`) is built from Debian
packages, bundled with flix, packed as squashfs, and shipped via a rolling
GitHub release that hosts pull with systemd-sysupdate.

## Layout

- `build/build.sh`: builds one arch into `tools-<version>-<arch>.raw`
- `build/smoke.sh`: checks a built image has the expected entry points
- `build/sources.sh`: fetches the Debian source of the bundled packages
- `build/flix.sh`: vendored from flatcar/sysext-bakery (Apache-2.0)
- `build/Dockerfile`: the Debian base tag, never built
- `extensions/tools/{packages,binaries,resources,overlay}`: what goes in the
  sysext; list new tools in `build/smoke.sh` too
- `examples/`, `docs/`: host-side provisioning

## Tech stack

Bash, Docker, GitHub Actions. In-container: patchelf, squashfs-tools,
bubblewrap.

## Style

Senior DevOps engineer. OpenBSD mindset. Unix philosophy.
Write code like a human, not a language model.

- Clean, minimal, no ai-slop. No filler words ("comprehensive", "robust",
  "leverage", "streamline", "utilize", "facilitate", "enhanced", "seamless").
- Comments only where a human would put them. Explain *why*, not *what*.
- Flat over nested. Early returns over deep indentation.
- Shell: pass shellcheck and shfmt clean (2-space indent, see .editorconfig).
  Do not touch `build/flix.sh`; it is vendored and excluded from linting.

## Git

Conventional commits, enforced by commitlint.

- Max 80 chars header, lowercase, no body unless necessary
- No co-authored-by or similar trailers
- Always rebase; keep history clean before merging. GitHub cannot sign
  rebase merges, so they only land on main via admin bypass; squash merges
  stay signed.
- Ask before deleting branches

## CI

- `build`: builds x86-64 and smoke-tests on every PR
- `release`: weekly (Fri) + on main; x86-64 only. Images are reproducible,
  so it publishes only when an image hash changed; transfer edits are uploaded
  in place, a manual dispatch always publishes. Every publish makes each host
  download ~80 MB.
- `lint`: MegaLinter (terraform flavor)
- `commit-lint`
- `dependabot-auto-merge`: non-major only, squash, not rebase. Only `build`
  is a required check, so it merges once that passes.

Pin every action to a commit SHA. Keep workflow permissions minimal.

## Web research

DevOps tooling changes fast. Check current upstream docs (Flatcar sysext,
sysext-bakery, systemd-sysupdate) before changing the build or provisioning.
Prefer context7 MCP, fall back to web search.

## Language

Respond in the language the user writes in.
