**OPXdemon 1.4** — auto payload refresh + USB Wi-Fi in the VM, by **OP AMINUL FF** / **OPX**.

### What's new in 1.4
- **Automatic payload refresh**: the rootless engine now compares the
  core-files release manifest with what is installed on the device and
  re-downloads only the changed files (QEMU / kernel / initrd / rootfs)
  before the next VM boot. Ship a payload update once — every install picks
  it up on its next start.
- **USB Wi-Fi in the guest (all architectures)**: every rootfs now bundles
  160+ wireless kernel modules (`mac80211`, `cfg80211`, `rtl8xxxu` incl.
  RTL8188FTV / 8188EU / 8192CU / 8723BU, `rt2800usb` + rt2x00, `mt76x0u` /
  `mt76x2u` / `mt7601u`, `ath9k_htc`, `zd1211rw`, `rtw88`/`rtw89`) and the
  full firmware set (realtek / ralink / mediatek / atheros / zd1211), so USB
  Wi-Fi adapters passed into the VM work with monitor mode + injection.
- Existing 1.3 installs update automatically on the next VM start (the new
  rootfs downloads once, ~460 MB; files are verified by sha256 and replaced
  atomically — an interrupted update never breaks the engine).
- versionCode **4**, versionName **1.4**.

### Assets
- `OPXdemon-1.4.apk` — the app (debug-signed, sideloadable)

### Payloads (unchanged set, all on the "chroot + rootless core files" release)
- `rootfs.imgz` / `rootfs-arm.imgz` / `rootfs-i386.imgz` / `rootfs-amd64.imgz`
  — updated with the full wireless driver + firmware set, boot-verified in
  QEMU (`modprobe rtl8xxxu rt2800usb mt76x2u ath9k_htc` all succeed)

> For authorized security testing only. You are responsible for complying with all applicable laws.
