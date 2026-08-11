#!/bin/sh
# OPXdemon final rebrand pass: remove every remaining user-facing/in-repo "Stryker"
# while preserving the payload-coupled guest-side markers that the downloaded
# rootfs/chroot binaries hardwire (they cannot be rebuilt from this repo):
#   /sdcard/Stryker (guest share path, 9p fstab + agentd mkdirs)
#   strykershare (9p mount_tag), stryker-agentd/-ptyd/-agent.service/-sshkeys.service,
#   /etc/modules-load.d/stryker.conf, stryker.rootless=1, guest user "stryker"
cd /home/daytona/codebase || exit 1
ROOT=/home/daytona/codebase

echo '=== PRE: JNI symbols in native code ==='
grep -rn 'Java_com_stryker' app/src/main/jni terminal/src/main/cpp 2>/dev/null
echo '--- neigh.c stryker line ---'
grep -n -i 'stryker' app/src/main/jni/neigh.c 2>/dev/null

# ---- 1. GLOBAL lowercase rename (content) ----
FILES=$(grep -ril 'stryker' \
  app/src/main/java terminal/src/main/java \
  app/src/main/res \
  app/src/main/assets/bootroot app/src/main/assets/bootroot_env \
  app/src/main/assets/install_xfce.sh app/src/main/assets/stryker_profile.sh \
  terminal/src/main/assets/bin \
  terminal/src/main/res \
  app/src/main/jni/neigh.c 2>/dev/null \
  | grep -v -E 'devices\.txt|routes\.txt|pixie_verified\.txt|AndroidManifest\.xml')

echo "=== global rename on $(echo "$FILES" | wc -l) files ==="
for f in $FILES; do
  [ -f "$f" ] || continue
  perl -pi -e 's/STRYKER/OPXDEMON/g; s/Stryker/OPXDemon/g; s/stryker/opxdemon/g;' "$f"
done

# ---- 2. RESTORE payload-coupled tokens + repo URLs ----
echo '=== restoring payload-coupled tokens ==='
for f in $FILES; do
  [ -f "$f" ] || continue
  perl -pi -e '
    s{/sdcard/OPXDemon}{/sdcard/Stryker}g;
    s{opxdemon-agentd}{stryker-agentd}g;
    s{opxdemon-agent\.service}{stryker-agent.service}g;
    s{opxdemon-ptyd}{stryker-ptyd}g;
    s{/etc/modules-load\.d/opxdemon\.conf}{/etc/modules-load.d/stryker.conf}g;
    s{opxdemon\.rootless=1}{stryker.rootless=1}g;
    s{opxdemonshare}{strykershare}g;
    s{opxdemon-screen\.ps1}{stryker-screen.ps1}g;
    s{mahmudabegum8859-design/opxdemonapp}{mahmudabegum8859-design/strykerapp}g;
  ' "$f"
done

# ---- 3. Targeted: rootless boot prompt match must keep guest user "stryker" ----
perl -pi -e 's{line\.contains\("opxdemon"\)}{line.contains("stryker")}g' \
  app/src/main/java/com/opxdemon/appintro/slides/SlideQemuInstall.java

# ---- 4. bootroot: bind HOST branded folder OPXDemon -> chroot payload path /sdcard/Stryker ----
BR=app/src/main/assets/bootroot
perl -pi -e '
  s{sdcard/OPXDemon}{sdcard/Stryker}g;
  s{mount -o bind "\$sdcard/Stryker" "\$MNT/sdcard/Stryker"}{mount -o bind "\$sdcard/OPXDemon" "\$MNT/sdcard/Stryker"}g;
  s{mkdir -p "\$sdcard/Stryker"}{mkdir -p "\$sdcard/OPXDemon"}g;
' "$BR"

# ---- 5. Dead theme styles ----
perl -pi -e 's/Theme\.stryker/Theme.OPXDemon/g; s/Theme\.opxdemon/Theme.OPXDemon/g;' \
  app/src/main/res/values/values/themes.xml app/src/main/res/values/values-night/themes.xml

# ---- 6. JNI C symbols ----
perl -pi -e 's/Java_com_stryker_terminal_backend_JNI_/Java_com_opxdemon_terminal_backend_JNI_/g' \
  terminal/src/main/cpp/terminal.cpp

# ---- 7. GitHub URLs (all files, both mangled forms) ----
for f in $FILES; do
  [ -f "$f" ] || continue
  perl -pi -e '
    s#https://github\.com/zalexdev/opxdemonapp#https://github.com/mahmudabegum8859-design/strykerapp#g;
    s#https://github\.com/zalexdev/strykerapp#https://github.com/mahmudabegum8859-design/strykerapp#g;
  ' "$f"
done

# ---- 8. File renames ----
echo
echo '=== file renames ==='
git mv app/src/main/assets/stryker app/src/main/assets/opxdemon 2>/dev/null && echo 'stryker -> opxdemon'
git mv app/src/main/assets/stryker_profile.sh app/src/main/assets/opxdemon_profile.sh 2>/dev/null && echo 'stryker_profile.sh -> opxdemon_profile.sh'
git mv app/src/main/assets/rootless/stryker-guest-core.tar app/src/main/assets/rootless/opxdemon-guest-core.tar 2>/dev/null && echo 'stryker-guest-core.tar -> opxdemon-guest-core.tar'
git mv terminal/src/main/assets/bin/stryker-ch terminal/src/main/assets/bin/opxdemon-ch 2>/dev/null && echo 'stryker-ch -> opxdemon-ch'
git mv terminal/src/main/res/drawable/strykerdefence.xml terminal/src/main/res/drawable/opxdemondefence.xml 2>/dev/null && echo 'strykerdefence -> opxdemondefence'

# ---- 9. Guest-core tar: rebrand banners/tags (agentd/ptyd names preserved) ----
echo
echo '=== guest-core tar rebuild ==='
TAR=$ROOT/app/src/main/assets/rootless/opxdemon-guest-core.tar
if [ -f "$TAR" ]; then
  rm -rf /tmp/gc2 && mkdir -p /tmp/gc2
  tar -xf "$TAR" -C /tmp/gc2
  # megacut.py: user-visible banner
  perl -pi -e 's/Stryker/OPXdemon/g; s/@zalexdev/OP AMINUL FF/g; s#github\.com/stryker-project#github.com/mahmudabegum8859-design/strykerapp#g; s#t\.me/opxdemonapp#t.me/strykerapp#g;' \
    /tmp/gc2/CORE/MegaCut/megacut.py
  # checker.py: credit comment
  perl -pi -e 's/Stryker/OPXdemon/g; s/ZalexDev/OP AMINUL FF/g; s#github\.com/stryker-project#github.com/mahmudabegum8859-design/strykerapp#g;' \
    /tmp/gc2/exploits/checker.py
  # pixie.py: protocol tag paired with AdvancedProcess.MACHINE_PREFIX -> OPXDEMON:
  perl -pi -e "s/STRYKER_TAG = 'STRYKER:'/STRYKER_TAG = 'OPXDEMON:'/; s/stryker-wps-/opxdemon-wps-/g; s/\.stryker/.opxdemon/g; s/Stryker/OPXdemon/g;" \
    /tmp/gc2/CORE/PixieWps/pixie.py
  cd /tmp/gc2 && tar -cf "$TAR.tmp" $(ls -A) && mv "$TAR.tmp" "$TAR"
  cd "$ROOT"
  echo "tar rebuilt: $(ls -la "$TAR" | awk '{print $5}') bytes"
  echo '--- tar entries still containing agentd (must keep names) ---'
  tar -tf "$TAR" | grep -i 'agentd\|ptyd' | head -4
fi

echo
echo '=== DONE ==='
