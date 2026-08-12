**OPXdemon 1.5** — QEMU boot fix + USB Wi-Fi enumeration, by **OP AMINUL FF** / **OPX**.

### What's new in 1.5

- **Fixed "QEMU exited during boot (code 159)" (SIGSYS).** The rootless engine now ships
  bionic-linked QEMU 11.0.2 builds for **all four** guest architectures (arm64, armhf,
  i386, amd64). The previous musl-static build issued a syscall the Android app-sandbox
  seccomp policy blocks, so QEMU died at startup. The bionic builds run under the policy —
  matching the original zalexdev engine that boots on device.
- **USB Wi-Fi adapters now enumerate at the right speed.** QEMU's upstream
  `USBDEVFS_GET_SPEED` ioctl bug (NULL argument, since 2021) made every passed-through
  adapter report as low-speed, so the guest failed enumeration with
  `Invalid ep0 maxpacket: 64`. The ioctl is patched, the correct speed is reported, and
  monitor mode + injection work with supported dongles (rtl8xxxu incl. RTL8188FTV,
  rt2800usb, mt76x0u/x2u, ath9k_htc, zd1211rw — drivers + firmware ship in the rootfs).
- **Multi-arch libslirp fix.** The armhf / i386 / amd64 QEMU binaries are bionic-linked
  against the shared `libslirp.so` (like arm64), so the engine now downloads and verifies
  `libslirp.so` for **every** guest architecture — previously only arm64 got it and the
  other guests would fail to start on a device.
- **Payload refresh self-repairs.** The engine now refreshes changed payloads *and*
  installs missing files (e.g. `libslirp.so` on a pre-1.5 install) before every boot, so a
  stale or interrupted install fixes itself instead of failing with
  "Rootless artifacts not installed".
- versionCode **6**, versionName **1.5**.

> **Tip for existing installs:** open the app and start the VM again — it downloads the
> new QEMU once (~36 MB) and boots with the fix. No reinstall needed.

### Assets

- `OPXdemon-1.5.apk` — the app (debug-signed, sideloadable)

> For authorized security testing only. You are responsible for complying with all applicable laws.
