#!/bin/sh
cd /home/daytona/codebase || exit 1

echo '=== 1. bootroot sdcard mount: ORIGINAL vs CURRENT ==='
echo '--- original (HEAD~1) ---'
git show HEAD~1:app/src/main/assets/bootroot 2>/dev/null | grep -n 'OPXDemon\|Stryker\|f_mount_sdcard\|bind' | head -12
echo '--- current ---'
grep -n 'OPXDemon\|Stryker\|f_mount_sdcard\|bind' app/src/main/assets/bootroot | head -12

echo
echo '=== 2. Core.java 700-742 (mount checks) ==='
sed -n '700,742p' app/src/main/java/com/opxdemon/utils/Core.java

echo
echo '=== 3. resolveShareDir definition ==='
grep -rn 'File resolveShareDir\|String resolveShareDir' app/src/main/java --include='*.java' | head -3

echo
echo '=== 4. terminal JNI loading ==='
grep -rn 'loadLibrary\|RegisterNatives' terminal/src NeoTermBridge/src 2>/dev/null | head -6
echo '--- native method decls (where createSubprocess declared) ---'
grep -rln 'createSubprocess' terminal/src NeoTermBridge/src --include='*.kt' --include='*.java' 2>/dev/null | head -4

echo
echo '=== 5. AdvancedProcess head + MACHINE_PREFIX use ==='
grep -n 'MACHINE_PREFIX' app/src/main/java/com/opxdemon/utils/AdvancedProcess.java app/src/main/java/com/opxdemon/utils/AdvancedProcessList.java 2>/dev/null | head -6
echo '--- app pixie parser ---'
grep -rln 'PixieWps\|pixie' app/src/main/java 2>/dev/null | head -8

echo
echo '=== 6. strykerdefence drawable location ==='
find terminal/src app/src -iname '*strykerdefence*' -o -iname '*defence*' 2>/dev/null | head -6

echo
echo '=== 7. terminal module res strings with stryker ==='
grep -rni 'stryker' terminal/src/main/res 2>/dev/null | head -8
