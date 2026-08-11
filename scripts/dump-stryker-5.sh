#!/bin/sh
cd /home/daytona/codebase || exit 1

echo '=== 1. AdvancedProcess.java 80-160 ==='
sed -n '80,160p' app/src/main/java/com/opxdemon/utils/AdvancedProcess.java

echo
echo '=== 2. MainActivity.copyAssets body ==='
sed -n '638,690p' app/src/main/java/com/opxdemon/MainActivity.java

echo
echo '=== 3. assets/stryker wrapper invocations ==='
grep -rn 'files/stryker\b\|files/stryker"\|"stryker"' app/src/main/java terminal/src 2>/dev/null | head -8

echo
echo '=== 4. ORIGINAL bootroot sdcard mount (HEAD~2, pre-turn1) ==='
git show HEAD~2:app/src/main/assets/bootroot 2>/dev/null | grep -n 'sdcard' | head -8

echo
echo '=== 5. ORIGINAL Core getShareRoot + sdcard mapping (HEAD~2) ==='
git show HEAD~2:app/src/main/java/com/zalexdev/stryker/utils/Core.java 2>/dev/null | grep -n 'getShareRoot\|getStorage() + \|Stryker' | head -10

echo
echo '=== 6. chroot tar fstab/sdcard refs ==='
curl -fsSL -o /tmp/cd2.tar.gz https://github.com/mahmudabegum8859-design/strykerapp/releases/download/v1.1/chroot64-debian.tar.gz
echo '--- fstab entries ---'
zgrep -a -o '/etc/fstab' /tmp/cd2.tar.gz | head -1
zgrep -a -A2 -B2 'sdcard' /tmp/cd2.tar.gz 2>/dev/null | head -c 800
rm -f /tmp/cd2.tar.gz
