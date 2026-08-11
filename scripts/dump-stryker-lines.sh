#!/bin/sh
# Dump every remaining stryker line (content) to drive precise replacements.
cd /home/daytona/codebase || exit 1

echo '=== JAVA + RES (app/src/main) ==='
grep -rni 'stryker' app/src/main/java app/src/main/res 2>/dev/null \
  | grep -v -i -E 'github.com/zalexdev/strykerapp|mahmudabegum8859-design/strykerapp' \
  | head -230

echo
echo '=== ASSETS SCRIPTS (no extension + .sh) ==='
for f in app/src/main/assets/bootroot app/src/main/assets/bootroot_env app/src/main/assets/killroot app/src/main/assets/chroot_exec app/src/main/assets/bash_exec app/src/main/assets/stryker app/src/main/assets/changemac app/src/main/assets/stryker_profile.sh app/src/main/assets/install_xfce.sh app/src/main/assets/uninstall_xfce.sh; do
  [ -f "$f" ] && grep -ni 'stryker' "$f" | sed "s#^#$f:#"
done

echo
echo '=== TERMINAL MODULE ==='
grep -rni 'stryker' terminal/src 2>/dev/null | head -40

echo
echo '=== MANIFEST + JNI + MISC ==='
grep -ni 'stryker' app/src/main/AndroidManifest.xml app/src/main/jni/neigh.c app/src/main/assets/devices.txt app/src/main/assets/routes.txt 2>/dev/null | head -10

echo
echo '=== InstallService: which chroot tars does the app install? ==='
grep -n 'tar.gz\|chroot\|debian\|\.imgz\|download' app/src/main/java/com/opxdemon/install/InstallService.java | head -20

echo
echo '=== strykershare in app ==='
grep -rni 'strykershare' app/src terminal/src 2>/dev/null | head -10

echo
echo '=== wrapper script stryker (assets) content ==='
cat app/src/main/assets/stryker 2>/dev/null

echo
echo '=== where is asset wrapper copied/executed ==='
grep -rn 'files/" + "\|filesDir.*stryker\|getFilesDir().*stryker\|copyAsset\|assets/stryker\|"stryker"' app/src/main/java terminal/src 2>/dev/null | grep -i stryker | head -15
