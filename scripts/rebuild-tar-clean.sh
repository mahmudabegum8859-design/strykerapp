#!/bin/sh
cd /home/daytona/codebase || exit 1
ROOT=/home/daytona/codebase
TAR=$ROOT/app/src/main/assets/rootless/opxdemon-guest-core.tar

# Extract the ORIGINAL tar from git HEAD (before any edits)
rm -rf /tmp/gc3 && mkdir -p /tmp/gc3
git show HEAD:app/src/main/assets/rootless/stryker-guest-core.tar > /tmp/gc3/orig.tar
tar -xf /tmp/gc3/orig.tar -C /tmp/gc3
echo '=== original megacut line 9/32/33 ==='
sed -n '9p;32p;33p' /tmp/gc3/CORE/MegaCut/megacut.py | cut -c1-120

# --- megacut.py: clean targeted rebrand (proper @ escaping) ---
perl -pi -e '
  s{Stryker}{OPXdemon}g;
  s{\@zalexdev}{OP AMINUL FF}g;
  s#github\.com/stryker-project#github.com/mahmudabegum8859-design/strykerapp#g;
  s#strykerapp/app#strykerapp#g;
  s{stryker-project}{the OPXdemon project}g;
' /tmp/gc3/CORE/MegaCut/megacut.py

# --- checker.py ---
perl -pi -e '
  s{Stryker}{OPXdemon}g;
  s{ZalexDev}{OP AMINUL FF}g;
  s#github\.com/stryker-project#github.com/mahmudabegum8859-design/strykerapp#g;
' /tmp/gc3/exploits/checker.py

# --- pixie.py: protocol tag pairs with AdvancedProcess.MACHINE_PREFIX ---
perl -pi -e "
  s{STRYKER_TAG = 'STRYKER:'}{STRYKER_TAG = 'OPXDEMON:'};
  s{stryker-wps-}{opxdemon-wps-}g;
  s{\.stryker}{.opxdemon}g;
  s{Stryker}{OPXdemon}g;
" /tmp/gc3/CORE/PixieWps/pixie.py

echo '=== megacut AFTER ==='
sed -n '9p;32p;33p' /tmp/gc3/CORE/MegaCut/megacut.py | cut -c1-200
echo '=== pixie tags ==='
grep -n "STRYKER_TAG\|opxdemon-wps\|\.opxdemon" /tmp/gc3/CORE/PixieWps/pixie.py | head -5
echo '=== checker ==='
grep -n 'OP AMINUL\|OPXdemon' /tmp/gc3/exploits/checker.py | head -3

# --- rebuild tar with identical structure ---
cd /tmp/gc3 && tar -cf "$TAR" CORE exploits usr 2>/dev/null || tar -cf "$TAR" $(ls -A)
cd "$ROOT"
echo
echo "tar rebuilt: $(ls -la "$TAR" | awk '{print $5}') bytes"
tar -tf "$TAR" | head -6
echo '--- agentd/ptyd entries preserved? ---'
tar -tf "$TAR" | grep -c 'stryker-agentd\|stryker-ptyd'
echo '--- no @zalexdev / stryker-project leftovers ---'
tar -xf "$TAR" -C /tmp/gc3 2>/dev/null
grep -rn '@zalexdev\|stryker-project\|ZalexDev' /tmp/gc3 2>/dev/null | head -4
echo '(none above = clean)'
