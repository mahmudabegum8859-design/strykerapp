#!/usr/bin/env bash
# ============================================================================
# add-wifi-firmware.sh — inject USB Wi-Fi firmware into an OPXdemon rootfs.imgz
# ============================================================================
# Why this exists:
#   The stock Debian guest kernels already ship EVERYTHING needed for USB
#   Wi-Fi as loadable modules (verified in the shipped payloads):
#     - net/mac80211 + net/wireless/cfg80211
#     - Realtek : rtl8xxxu (RTL8188FU/FTV, 8188EU, 8192CU, 8192EU, 8723BU,
#                 8710BU, 8192FU), rtlwifi, rtw88, rtw89
#     - Ralink  : rt2800usb + the whole rt2x00 family
#     - MediaTek: mt76x0u, mt76x2u, mt7601u, mt7921u, mt7601u
#     - Atheros : ath9k_htc (AR9271 / AR7010), ath10k, ath11k
#     - ZyDAS   : zd1211rw
#   What is missing from the shipped rootfs images is only the FIRMWARE files
#   (/lib/firmware). This script merges the firmware from extracted Debian
#   firmware-* packages into a rootfs.imgz using debugfs (no loop mounts or
#   FUSE required), then re-gzips the image in place.
#
# Usage:
#   sh scripts/add-wifi-firmware.sh <rootfs.imgz> [firmware-root]
#
#   firmware-root  extracted firmware tree (default /tmp/fw/fwroot/usr/lib/firmware)
#                  from the Debian firmware-realtek / firmware-ralink /
#                  firmware-mediatek / firmware-atheros / firmware-misc-nonfree
#                  and firmware-zd1211 packages (dpkg-deb -x each).
#
#   The input file is REPLACED by the updated image (a .bak is kept).
#
# Verified: on every shipped architecture (arm64, armhf, i386, amd64) the
# resulting rootfs boots in QEMU and `modprobe rtl8xxxu rt2800usb mt76x2u
# ath9k_htc` all succeed (mac80211/cfg80211 attach), which is the state
# required for USB Wi-Fi monitor mode / injection in the guest.
# ============================================================================
set -euo pipefail

IMG="${1:?usage: add-wifi-firmware.sh <rootfs.imgz> [firmware-root]}"
FW="${2:-/tmp/fw/fwroot/usr/lib/firmware}"
[ -d "$FW" ] || { echo "firmware root not found: $FW"; exit 1; }
command -v debugfs >/dev/null || { echo "debugfs (e2fsprogs) required"; exit 1; }

RAW="$IMG.raw"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> decompressing $IMG"
gunzip -c "$IMG" > "$RAW"

echo "==> generating debugfs script (wifi-relevant firmware only)"
python3 - "$FW" > "$WORK/fw-script.txt" <<'PYEOF'
import os, re, sys
fwroot = sys.argv[1]
def wifi_relevant(rel):
    top = rel.split('/')[0]
    if top in ('rtlwifi', 'rtl_bt', 'zd1211', 'ath9k_htc'):
        return True
    if top.endswith(('.bin', '.fw')):
        b = top
        if re.match(r'rt\d+', b) or re.match(r'mt\d+', b):
            return True
        if b in ('htc_7010.fw', 'htc_9271.fw', 'ar5523.bin'):
            return True
    return False
dirs, files = set(), []
for dp, _, fns in os.walk(fwroot):
    for fn in fns:
        rel = os.path.relpath(os.path.join(dp, fn), fwroot)
        if wifi_relevant(rel):
            d = '/usr/lib/firmware/' + os.path.dirname(rel)
            parts = d.split('/')
            for i in range(2, len(parts) + 1):
                dirs.add('/'.join(parts[:i]))
            files.append((os.path.join(dp, fn), '/usr/lib/firmware/' + rel))
for d in sorted(dirs, key=lambda x: x.count('/')):
    print('mkdir %s' % d)
for f, d in files:
    print('write %s %s' % (f, d))
print('files queued: %d' % len(files), file=sys.stderr)
PYEOF

echo "==> injecting firmware into $RAW"
debugfs -w -f "$WORK/fw-script.txt" "$RAW" 2>&1 | grep -iE "No space|error" && { echo "debugfs reported errors above"; exit 1; } || true

echo "==> verifying a sample of files"
for f in rt2860.bin rt2870.bin mt7601u.bin mt7662.bin rtlwifi/rtl8188fufw.bin htc_9271.fw; do
    debugfs -R "stat /usr/lib/firmware/$f" "$RAW" 2>/dev/null | grep -q "Inode:" || { echo "MISSING /usr/lib/firmware/$f"; exit 1; }
done
echo "    all sample firmware files present"

echo "==> re-compressing"
cp "$IMG" "$IMG.bak"
gzip -1 -f "$RAW"
mv "$RAW.gz" "$IMG"
echo "==> done: $IMG"
ls -la "$IMG"
