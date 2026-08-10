#!/bin/sh
# fix-assets.sh — second rebrand pass for extension-less asset scripts, .ducky
# payload texts, and a few lowercase cosmetic leftovers. Keeps all preserved
# protocol/payload strings (see rename-opxdemon.sh header).
set -e
cd "$(dirname "$0")/.."

FILES=$(find app/src/main/assets -type f \
  \( -name '*.ducky' -o -name '*.sh' -o ! -name '*.*' -o -name '*.txt' \) \
  -not -name 'busybox64' -not -name 'devices.txt' -not -name 'pixie_verified.txt' -not -name 'routes.txt')

perl -pi -e '
  s/com\.zalexdev\.stryker/com.opxdemon/g;
  s/StrykerOSS/OPXdemon/g;
  s/Stryker/OPXDemon/g;
  s/99stryker/99opxdemon/g;
  s/localhost stryker/localhost opxdemon/g;
  s/STRYKER SHELL PROMPT/OPXDEMON SHELL PROMPT/g;
' $FILES

# About-page link strings deep inside the large values/strings.xml.
perl -pi -e '
  s{zalexdev\.com</string>}{github.com/mahmudabegum8859-design/strykerapp</string>}g;
  s{github\.com/zalexdev/strykerapp</string>}{github.com/mahmudabegum8859-design/strykerapp</string>}g;
' app/src/main/res/values/strings.xml

# Cosmetic lowercase leftovers in Java.
perl -pi -e '
  s{Download/stryker\.apk}{Download/opxdemon.apk}g;
  s/stryker_news/opxdemon_news/g;
  s/"stryker\.exploit"/"opxdemon.exploit"/g;
' app/src/main/java/com/opxdemon/appintro/slides/Slide3.java \
  app/src/main/java/com/opxdemon/dashboard/NewsAdapter.java \
  app/src/main/java/com/opxdemon/arsenal/RunExploitSheet.java

echo "=== fixed. verify: ==="
grep -n 'APP_PGK_NAME' app/src/main/assets/bootroot_env
grep -n 'OPXDemon MAC changer' app/src/main/assets/changemac
grep -n 'Hello from OPXdemon' app/src/main/assets/hid/payloads/linux_terminal.ducky
