#!/bin/sh
# Check downloaded payloads for the last unknowns:
#  - rootfs exact stryker strings (agentd naming, share dir)
#  - chroot64-debian exact stryker contexts
#  - legacy chroot tars for /data/local/stryker (blocks mount-path rename)
cd /home/daytona/codebase || exit 1

B=https://github.com/mahmudabegum8859-design/strykerapp/releases/download/v1.1

echo '=== ROOTFS exact stryker strings ==='
curl -fsSL -o /tmp/rf.imgz $B/rootfs.imgz
zgrep -a -o 'stryker[a-zA-Z0-9_.-]*' /tmp/rf.imgz 2>/dev/null | sort | uniq -c | sort -rn | head -20
echo '--- stryker contexts (60c) ---'
zgrep -a -o '.\{0,50\}stryker.\{0,70\}' /tmp/rf.imgz 2>/dev/null | sort -u | head -30
echo '--- stryker-agentd as filename? ---'
zgrep -a -o '[a-zA-Z0-9_/.-]*stryker-agent[a-zA-Z0-9_/.-]*' /tmp/rf.imgz 2>/dev/null | sort -u | head -10
rm -f /tmp/rf.imgz

echo
echo '=== CHROOT64-DEBIAN exact stryker strings ==='
curl -fsSL -o /tmp/cd.tar.gz $B/chroot64-debian.tar.gz
zgrep -a -o '.\{0,50\}stryker.\{0,70\}' /tmp/cd.tar.gz 2>/dev/null | sort -u | head -30
rm -f /tmp/cd.tar.gz

echo
echo '=== LEGACY CHROOT TARS: /data/local/stryker + strykershare + /sdcard/Stryker counts ==='
for f in chroot64.tar.gz chroot32.tar.gz chroot_v5b_64.tar.gz 4.0.tar.gz; do
  echo "--- $f ---"
  curl -fsSL -o /tmp/leg.tar.gz $B/$f || { echo 'download failed'; continue; }
  for p in '/data/local/stryker' 'strykershare' '/sdcard/Stryker'; do
    c=$(zgrep -ac "$p" /tmp/leg.tar.gz 2>/dev/null)
    echo "  $p = $c"
  done
  rm -f /tmp/leg.tar.gz
done

echo
echo '=== DISK ==='
df -h / | tail -1
