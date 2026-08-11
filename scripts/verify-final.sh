#!/bin/sh
cd /home/daytona/codebase || exit 1

echo '=== bootroot mount section (must: host OPXDemon -> chroot Stryker) ==='
sed -n '20,24p;36,60p' app/src/main/assets/bootroot

echo
echo '=== bootroot remaining stryker lines ==='
grep -n -i 'stryker' app/src/main/assets/bootroot

echo
echo '=== strings.xml remaining stryker lines ==='
grep -n -i 'stryker' app/src/main/res/values/strings.xml | cut -c1-140

echo
echo '=== SlideQemuInstall restore ==='
grep -n 'contains(' app/src/main/java/com/opxdemon/appintro/slides/SlideQemuInstall.java | head -3

echo
echo '=== opxdemon-ch remaining stryker lines ==='
grep -n -i 'stryker' terminal/src/main/assets/bin/opxdemon-ch

echo
echo '=== opxdemon_profile.sh banner ==='
grep -n -i 'opxdemon\|greeted' app/src/main/assets/opxdemon_profile.sh | head -6

echo
echo '=== stray zalexdev outside payload URLs / notices ==='
grep -rni 'zalexdev' app/src terminal/src NeoTermBridge/src Xorg/src NeoLang/src chrome-tabs/src 2>/dev/null \
  | grep -v -i -E 'github\.com/zalexdev' | head -10

echo
echo '=== guest-core tar: megacut + pixie tags ==='
tar -xf app/src/main/assets/rootless/opxdemon-guest-core.tar -C /tmp/gc2 2>/dev/null
grep -n 'OPXdemon\|OPXDEMON' /tmp/gc2/CORE/MegaCut/megacut.py | head -4
grep -n 'STRYKER_TAG' /tmp/gc2/CORE/PixieWps/pixie.py | head -2
grep -n '\.opxdemon' /tmp/gc2/CORE/PixieWps/pixie.py | head -3

echo
echo '=== terminal.cpp JNI + neigh.c ==='
grep -c 'Java_com_opxdemon_terminal_backend_JNI_' terminal/src/main/cpp/terminal.cpp
grep -n 'Java_com_' app/src/main/jni/neigh.c

echo
echo '=== git status short (count) ==='
git status --short | wc -l
git status --short | grep -v -E '\.(java|kt|xml|gradle|md|json|properties|sh|pro|mk|aidl|c|txt|yml|yaml)$|app/src/main/assets/(bootroot|bootroot_env|killroot|changemac|chroot_exec|bash_exec|opxdemon|opxdemon_profile\.sh|install_xfce\.sh|uninstall_xfce\.sh|hid/|rootless/)' | head -10
