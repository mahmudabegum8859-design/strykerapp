#!/bin/sh
cd /home/daytona/codebase || exit 1

echo '=== ASSET SCRIPTS stryker lines ==='
for f in app/src/main/assets/bootroot app/src/main/assets/bootroot_env app/src/main/assets/install_xfce.sh app/src/main/assets/stryker_profile.sh; do
  echo "--- $f ---"
  grep -ni 'stryker' "$f"
done

echo
echo '=== TERMINAL MODULE stryker lines ==='
grep -rni 'stryker' terminal/src 2>/dev/null | head -35

echo
echo '=== ANDROIDMANIFEST stryker ==='
grep -ni 'stryker' app/src/main/AndroidManifest.xml

echo
echo '=== THEMES ==='
grep -n 'Theme' app/src/main/res/values/values/themes.xml app/src/main/res/values/values-night/themes.xml | head -8

echo
echo '=== devices.txt stryker occurrence ==='
grep -o -i '.\{0,80\}stryker.\{0,80\}' app/src/main/assets/devices.txt | head -3

echo
echo '=== pixie STRYKER: tag consumers in app ==='
grep -rn 'STRYKER:' app/src/main/java 2>/dev/null | head -8

echo
echo '=== who copies assets/stryker wrapper or bash_exec ==='
grep -rn 'bash_exec\|copyAsset\|ASSETS\b' app/src/main/java/com/opxdemon/MainActivity.java app/src/main/java/com/opxdemon/Initializing.java 2>/dev/null | head -20

echo
echo '=== resolveShareDir ==='
grep -n 'resolveShareDir' -A 12 app/src/main/java/com/opxdemon/utils/Core.java | head -18

echo
echo '=== stryker-screen / ps1 refs ==='
grep -rni 'stryker-screen\|\.ps1' app/src/main terminal/src 2>/dev/null | head -8

echo
echo '=== guest-core tar: markers produced ==='
grep -rn '__STRYKER\|STRYKER_TAG\|stryker.rootless\|\[STRYKER' /tmp/gc 2>/dev/null | head -12
