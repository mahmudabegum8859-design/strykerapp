**OPXdemon 1.1** — rebranded StrykerOSS fork by **OP AMINUL FF** / **OPX**.

### What's new
- Rebranded to **OPXdemon**: app name, package `com.opxdemon`, developer OP AMINUL FF, company OPX.
- Version **1.1** (versionCode 1).
- New **Tour Mode** (3rd setup mode): walk through every feature with nothing installed, downloaded or executed — no root, no chroot, no VM.
- Rooted mode installs the Debian trixie chroot from this release (`chroot64-debian.tar.gz`).
- Rootless mode installs the QEMU VM stack from this release (`qemu-system-aarch64`, `Image`, `initrd.img`, `libslirp.so`, `rootfs.imgz`).
- All payloads now download from **this** release (v1.1) — no more dependency on upstream releases.

### Assets
- `OPXdemon-1.1.apk` — the app (debug-signed, sideloadable)
- Rooted payloads: `chroot64-debian.tar.gz` (+ legacy `chroot64.tar.gz`, `chroot32.tar.gz`, `chroot_v5b_64.tar.gz`, `4.0.tar.gz`)
- Rootless payloads: `qemu-system-aarch64`, `Image`, `initrd.img`, `libslirp.so`, `rootfs.imgz`

> For authorized security testing only. You are responsible for complying with all applicable laws.
