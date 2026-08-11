#!/bin/sh
cd /home/daytona/codebase || exit 1
ROOT=/home/daytona/codebase
TAR=$ROOT/app/src/main/assets/rootless/opxdemon-guest-core.tar

rm -rf /tmp/gc2 && mkdir -p /tmp/gc2
tar -xf "$TAR" -C /tmp/gc2

echo '=== megacut.py BEFORE (lines 9, 32, 33) ==='
sed -n '9p;32p;33p' /tmp/gc2/CORE/MegaCut/megacut.py

perl -pi -e '
  s{^OP AMINUL FF#}{## }g;
  s{OP AMINUL FF    print\(}{    print(}g;
  s{by \@zalexdev\.}{by OP AMINUL FF.}g;
  s{by \@zalexdev \(ver 1\.0\)}{by OP AMINUL FF (ver 1.0)}g;
  s{for stryker-project}{for the OPXdemon project}g;
  s{github\.com/opxdemon-project}{github.com/mahmudabegum8859-design/strykerapp}g;
  s{mahmudabegum8859-design/strykerapp/app}{mahmudabegum8859-design/strykerapp}g;
' /tmp/gc2/CORE/MegaCut/megacut.py

echo '=== megacut.py AFTER ==='
sed -n '9p;32p;33p' /tmp/gc2/CORE/MegaCut/megacut.py

echo '=== checker.py credit line ==='
grep -n 'OP AMINUL\|OPXdemon' /tmp/gc2/exploits/checker.py | head -2

cd /tmp/gc2 && tar -cf "$TAR.tmp" $(ls -A) && mv "$TAR.tmp" "$TAR"
cd "$ROOT"
echo "tar rebuilt: $(ls -la "$TAR" | awk '{print $5}') bytes"
echo '--- no leftover @zalexdev or stryker-project in tar text ---'
tar -xf "$TAR" -C /tmp/gc2
grep -rn '@zalexdev\|stryker-project\|ZalexDev' /tmp/gc2 2>/dev/null | head -4
echo '(none above = clean)'
