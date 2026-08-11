**OPXdemon 1.3** — multi-architecture engine release by **OP AMINUL FF** / **OPX**.

### What's new in 1.3

- **All payloads now download from the `core-files` release** — every architecture's
  rooted chroot and rootless VM files live in one place, and the app picks the
  matching set automatically. No more v1.1 payload URLs.
- **Multi-architecture rootless VM**: the setup screen now lets you choose the guest
  architecture — **arm64** (the tested engine), **armhf**, **i386** or **amd64**.
- **New static QEMU emulators** for the armhf / i386 / amd64 guests
  (`qemu-system-arm`, `qemu-system-i386`, `qemu-system-x86_64`): fully static
  (musl, no external libs, slirp built in) — they run on any arm64 Android device
  without extra libraries.
- **Per-architecture kernels, initrds and rootfs** (`Image-arm`, `initrd-arm.img`,
  `rootfs-arm.imgz`, and the i386/amd64 variants) plus per-architecture Debian
  chroot archives for rooted mode. All are boot-verified in QEMU (reach the Debian
  login prompt); armhf / i386 / amd64 are **not** device-tested yet — flagged
  "Not Tested" in the release body.
- The rooted chroot always follows the device ABI (arm64 on this build).
- versionCode **3**, versionName **1.3**.

### Assets
- `OPXdemon-1.3.apk` — the app (debug-signed, sideloadable)

### Payloads (all on the "chroot + rootless core files" release)
- **arm64 (tested):** `qemu-system-aarch64`, `Image`, `initrd.img`, `libslirp.so`,
  `rootfs.imgz`, `chroot64-debian.tar.gz`
- **armhf / i386 / amd64 (boot-verified, not device-tested):** static QEMU binary +
  `Image-*`, `initrd-*.img`, `rootfs-*.imgz`, `chroot64-debian-*.tar.gz`

> For authorized security testing only. You are responsible for complying with all
> applicable laws.
