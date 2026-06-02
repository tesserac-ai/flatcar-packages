# flatcar-packages

Builds systemd-sysext images of extra CLI tools for Flatcar Container Linux.
The `tools` sysext (emacs-nox, ncdu, htop) is built from Alpine packages,
wrapped with flatwrap, packed as squashfs, and shipped via a rolling GitHub
release that hosts pull with systemd-sysupdate.

## Layout

- `build/build.sh`: builds one arch into `tools-<version>-<arch>.raw`
- `build/smoke.sh`: checks a built image has the expected entry points
- `build/flatwrap.sh`: vendored from flatcar/sysext-bakery (Apache-2.0)
- `build/Dockerfile`: declares the Alpine base; Dependabot bumps it
- `extensions/tools/{packages,binaries}`: what goes in the sysext
- `examples/`, `docs/`: host-side provisioning

## Tech stack

Bash, Docker, squashfs-tools (in-container), GitHub Actions.

## Style

Senior DevOps engineer. OpenBSD mindset. Unix philosophy.
Write code like a human, not a language model.

- Clean, minimal, no ai-slop. No filler words ("comprehensive", "robust",
  "leverage", "streamline", "utilize", "facilitate", "enhanced", "seamless").
- Comments only where a human would put them. Explain *why*, not *what*.
- Flat over nested. Early returns over deep indentation.
- Shell: pass shellcheck and shfmt clean (2-space indent, see .editorconfig).
  Do not touch `build/flatwrap.sh`; it is vendored and excluded from linting.

## Git

Conventional commits, enforced by commitlint.

- Max 80 chars header, lowercase, no body unless necessary
- No co-authored-by or similar trailers
- Always rebase; keep history clean before merging
- Ask before deleting branches

## CI

- `build`: builds x86-64 and smoke-tests on every PR
- `release`: weekly (Fri) + on main; manifest-gated rolling release
- `lint`: MegaLinter (terraform flavor)
- `commit-lint`, `dependabot-auto-merge`

Pin every action to a commit SHA. Keep workflow permissions minimal.

## Web research

DevOps tooling changes fast. Check current upstream docs (Flatcar sysext,
sysext-bakery, systemd-sysupdate) before changing the build or provisioning.
Prefer context7 MCP, fall back to web search.

## Language

Respond in the language the user writes in.
