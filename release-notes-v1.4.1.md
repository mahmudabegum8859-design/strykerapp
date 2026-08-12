**OPXdemon 1.4.1** — hotfix, by **OP AMINUL FF** / **OPX**.

### Fixed
- **"Size mismatch: got 462418320, expected 427974567" during rootless install.**
  The manifest's per-architecture arm64 entry still pointed at the previous
  rootfs size/sha256 while the release already served the new rootfs (USB
  Wi-Fi firmware release), so the freshly downloaded rootfs failed
  verification. All rootfs entries (flat + arm64 / armhf / i386 / amd64) now
  match the release exactly.
- **Installer self-heals on stale manifests.** If a payload download ever
  fails size/checksum verification again (e.g. a release updated between the
  manifest fetch and the download), the app now drops the cached manifest,
  fetches a fresh one and retries once — a payload update can never block the
  install again.

### Assets
- `OPXdemon-1.4.1.apk` — the app (debug-signed, sideloadable)

> For authorized security testing only. You are responsible for complying with all applicable laws.
