#!/bin/sh
cd /home/daytona/codebase || exit 1

echo '=== all Java_com_ symbols in native code ==='
grep -rhn 'Java_com_' app/src/main/jni terminal/src/main/cpp 2>/dev/null | grep -o 'Java_com_[A-Za-z0-9_]*' | sort -u

echo
echo '=== fix neigh.c symbol ==='
grep -n 'Java_com_' app/src/main/jni/neigh.c | head -2
perl -pi -e 's/Java_com_zalexdev_opxdemon_localnetwork_nonroot_Neighbours_nativeDump/Java_com_opxdemon_localnetwork_nonroot_Neighbours_nativeDump/g' app/src/main/jni/neigh.c
perl -pi -e 's/Java_com_zalexdev_stryker_localnetwork_nonroot_Neighbours_nativeDump/Java_com_opxdemon_localnetwork_nonroot_Neighbours_nativeDump/g' app/src/main/jni/neigh.c
echo 'after:'
grep -n 'Java_com_' app/src/main/jni/neigh.c | head -2

echo
echo '=== VERIFICATION: remaining stryker (case-insens), grouped by file ==='
grep -rni 'stryker' app/src terminal/src NeoTermBridge/src Xorg/src NeoLang/src chrome-tabs/src 2>/dev/null \
  | grep -v -E '^Binary' \
  | cut -d: -f1 | sort | uniq -c | sort -rn | head -40

echo
echo '=== VERIFICATION: the actual remaining lines (excluding known payload tokens) ==='
grep -rni 'stryker' app/src/main/java app/src/main/res terminal/src 2>/dev/null \
  | grep -v -i -E 'sdcard/Stryker|stryker-agentd|stryker-ptyd|stryker-agent\.service|stryker-sshkeys|stryker\.conf|stryker\.rootless|strykershare|contains\("stryker"\)|stryker-screen\.ps1|mahmudabegum8859-design/strykerapp|zalexdev/strykerapp' \
  | head -40

echo
echo '=== repo-wide (non-module) stryker ==='
grep -rni 'stryker' README.md opxdemon_manifest.json .github scripts 2>/dev/null | grep -v -E 'zalexdev/strykerapp|mahmudabegum8859-design/strykerapp|stryker-guest-core|/sdcard/Stryker' | head -12
