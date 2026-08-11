#!/bin/sh
# Audit remaining 'stryker' references to categorize: app-internal (safe to rename)
# vs payload-coupled (downloaded binaries/rootfs/chroot the app cannot rebuild).
cd /home/daytona/codebase || exit 1

echo '=== 1. DISK ==='
df -h / | tail -1

echo
echo '=== 2. REMAINING stryker in app/src/main (java+res+assets, excluding github URLs) ==='
grep -rni 'stryker' app/src/main 2>/dev/null \
  | grep -v -i -E 'github.com/zalexdev/strykerapp|mahmudabegum8859-design/strykerapp' \
  | grep -v -E '^Binary' | wc -l
echo '--- by file ---'
grep -rni 'stryker' app/src/main 2>/dev/null \
  | grep -v -i -E 'github.com/zalexdev/strykerapp|mahmudabegum8859-design/strykerapp' \
  | grep -v -E '^Binary' | cut -d: -f1 | sort | uniq -c | sort -rn

echo
echo '=== 3. OTHER MODULES ==='
for d in terminal/src NeoTermBridge/src Xorg/src NeoLang/src chrome-tabs/src; do
  echo "[$d] $(grep -rni 'stryker' $d 2>/dev/null | wc -l)"
done

echo
echo '=== 4. GUEST-CORE TAR (in-repo, rebuildable) ==='
if [ -d /tmp/gc ]; then
  echo '(still extracted at /tmp/gc)'
else
  rm -rf /tmp/gc && mkdir -p /tmp/gc
  tar -xf app/src/main/assets/rootless/stryker-guest-core.tar -C /tmp/gc 2>/dev/null
  echo '(re-extracted)'
fi
grep -rni 'stryker' /tmp/gc 2>/dev/null | grep -v -E '^Binary' | head -60

echo
echo '=== 5. CHROOT64-DEBIAN payload pattern counts ==='
curl -fsSL -o /tmp/cd.tar.gz https://github.com/mahmudabegum8859-design/strykerapp/releases/download/v1.1/chroot64-debian.tar.gz
for p in 'stryker_profile' '\[STRYKER\]' 'STRYKERBC1' 'STRYKERHTG1' '/data/local/stryker' 'STRYKER_PTY' 'strykershare' 'stryker-guest-core' '/sdcard/Stryker'; do
  c=$(zgrep -ac "$p" /tmp/cd.tar.gz 2>/dev/null)
  echo "$p = $c"
done
rm -f /tmp/cd.tar.gz

echo
echo '=== 6. ROOTFS payload pattern counts ==='
curl -fsSL -o /tmp/rootfs-a.imgz https://github.com/mahmudabegum8859-design/strykerapp/releases/download/v1.1/rootfs.imgz
for p in 'stryker_profile' '\[STRYKER\]' 'STRYKERBC1' 'STRYKERHTG1' '/data/local/stryker' 'STRYKER_PTY' 'strykershare' 'stryker-guest-core' '/sdcard/Stryker' 'stryker.rootless' 'org.stryker'; do
  c=$(zgrep -ac "$p" /tmp/rootfs-a.imgz 2>/dev/null)
  echo "$p = $c"
done
rm -f /tmp/rootfs-a.imgz

echo
echo '=== 7. INITRD payload pattern counts ==='
curl -fsSL -o /tmp/initrd-a.img https://github.com/mahmudabegum8859-design/strykerapp/releases/download/v1.1/initrd.img
for p in 'stryker' 'STRYKER' '/data/local' 'rootfs' ; do
  c=$(zgrep -ac "$p" /tmp/initrd-a.img 2>/dev/null)
  echo "$p = $c"
done
rm -f /tmp/initrd-a.img

echo
echo '=== 8. IMAGE kernel payload pattern counts ==='
curl -fsSL -o /tmp/Image-a https://github.com/mahmudabegum8859-design/strykerapp/releases/download/v1.1/Image
for p in 'stryker' 'STRYKER'; do
  c=$(grep -ac "$p" /tmp/Image-a 2>/dev/null)
  echo "$p = $c"
done
rm -f /tmp/Image-a

echo
echo '=== 9. QEMU binary stryker hits ==='
curl -fsSL -o /tmp/qemu-a https://github.com/mahmudabegum8859-design/strykerapp/releases/download/v1.1/qemu-system-aarch64
echo "stryker = $(grep -ac 'stryker' /tmp/qemu-a 2>/dev/null)"
rm -f /tmp/qemu-a

echo
echo '=== 10. SHARE-ROOT mapping + markers in app ==='
sed -n '300,320p;445,470p' app/src/main/java/com/opxdemon/utils/Core.java
echo '--- RootlessPaths ---'
cat app/src/main/java/com/opxdemon/engine/RootlessPaths.java
echo '--- [STRYKER] producer/consumer ---'
grep -rn '\[STRYKER\]' app/src/main terminal/src 2>/dev/null
echo '--- org.stryker in repo ---'
grep -rn 'org\.stryker' app/src terminal/src NeoTermBridge/src Xorg/src NeoLang/src chrome-tabs/src 2>/dev/null | head
