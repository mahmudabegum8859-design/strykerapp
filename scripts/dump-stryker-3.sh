#!/bin/sh
cd /home/daytona/codebase || exit 1

echo '=== A. terminal JNI: how are native methods registered? ==='
sed -n '1,60p' terminal/src/main/cpp/terminal.cpp
echo '--- kotlin native decl ---'
grep -rn 'external fun\|System.loadLibrary\|RegisterNatives\|JNI' terminal/src/main/java/com/opxdemon/terminal/backend/*.kt terminal/src/main/java/com/opxdemon/terminal/backend/**/*.kt 2>/dev/null | head -12

echo
echo '=== B. rootless resolveShareDir ==='
grep -rn 'resolveShareDir' -B2 -A14 app/src/main/java/com/opxdemon/engine/RootlessPaths.java app/src/main/java/com/opxdemon/engine/*.java 2>/dev/null | head -30

echo
echo '=== C. bootroot sdcard mount section ==='
grep -n 'mount\|/sdcard' app/src/main/assets/bootroot | head -25

echo
echo '=== D. app pixie engine: .stryker / STRYKER: / MACHINE_PREFIX usage ==='
grep -rn '\.stryker\|MACHINE_PREFIX\|AdvancedProcess' app/src/main/java 2>/dev/null | grep -vi 'stryker_profile\|stryker-guest\|stryker-vnc\|stryker-update\|stryker-\|stryker_logs\|stryker_arsenal\|stryker-templates\|stryker\.hid' | head -12

echo
echo '=== E. manifest theme attr + Theme.stryker refs ==='
grep -n 'android:theme' app/src/main/AndroidManifest.xml
grep -rn 'Theme\.stryker\|Theme\.OPXDemon' app/src/main --include='*.xml' 2>/dev/null | head -10

echo
echo '=== F. stryker-named drawables/resources ==='
find app/src/main/res -iname '*stryker*' | head -20

echo
echo '=== G. stryker-ch + android-su refs ==='
grep -rn 'stryker-ch\|android-su' app/src terminal/src --include='*.java' --include='*.kt' --include='*.xml' 2>/dev/null | head -12

echo
echo '=== H. staged/hidden file refs ==='
grep -rn 'stryker-guest-core\|stryker-vnc\|stryker-templates\|stryker\.log\|stryker-update' app/src terminal/src 2>/dev/null | head -12
