#!/bin/sh
# rename-opxdemon.sh — one-time mechanical rebrand: OPXDemon -> OPXdemon.
#
# Preserved on purpose (coupled to prebuilt payloads / user-specified URLs):
#   - /data/local/stryker  (chroot mount path baked into prebuilt Debian rootfs)
#   - /sdcard/Stryker      (storage dir baked into prebuilt rootfs/chroot tools)
#   - github.com/zalexdev/strykerapp release URLs (user-designated download sources)
#   - stryker-guest-core.tar asset name, USB gadget name, default VNC password,
#     boot-log detection strings, assets/stryker + stryker_profile.sh filenames
set -e
cd "$(dirname "$0")/.."

FILES=$(find . -type f \
  \( -name '*.java' -o -name '*.kt' -o -name '*.xml' -o -name '*.gradle' -o -name '*.md' \
     -o -name '*.json' -o -name '*.properties' -o -name '*.sh' -o -name '*.txt' \
     -o -name '*.yml' -o -name '*.yaml' -o -name '*.bat' -o -name '*.pro' -o -name '*.mk' \
     -o -name '*.cmake' -o -name '*.gitignore' -o -name 'stryker' -o -name '.name' \) \
  -not -path '*/.git/*' -not -path '*/.gradle/*' -not -path '*/build/*' -not -path '*/.idea/*' )

# 1) Protect the payload-coupled storage path during the capital-OPXDemon pass.
perl -pi -e 's{/sdcard/Stryker}{/sdcard/Stryker}g' $FILES

# 2) Branding / identity replacements (order matters).
perl -pi -e '
  s/com\.zalexdev\.stryker/com.opxdemon/g;
  s/com\.stryker\.terminal\.bridge/com.opxdemon.terminal.bridge/g;
  s/com\.stryker\.terminal/com.opxdemon.terminal/g;
  s/com\.stryker/com.opxdemon/g;
  s/OPXDEMON_RELEASE/OPXDEMON_RELEASE/g;
  s/OPXDemonEndpoints/OPXDemonEndpoints/g;
  s/OPXdemon/OPXdemon/g;
  s/Theme\.OPXDemon/Theme.OPXDemon/g;
  s/opxdemon_accent/opxdemon_accent/g;
  s/opxdemon_main_logo/opxdemon_main_logo/g;
  s/opxdemon_ota/opxdemon_ota/g;
  s/stryker_manifest\.json/opxdemon_manifest.json/g;
  s/OPXDemonApp/OPXDemonApp/g;
  s/OPXDemon\.apk/OPXDemon.apk/g;
  s/OPXDemon/OPXDemon/g;
' $FILES

# 3) Restore the protected storage path.
perl -pi -e 's{/sdcard/Stryker}{/sdcard/Stryker}g' $FILES

# 4) Move package source trees.
git mv app/src/main/java/com/zalexdev/stryker app/src/main/java/com/opxdemon
rmdir app/src/main/java/com/zalexdev 2>/dev/null || true

if [ -d terminal/src/main/java/com/stryker ]; then
  git mv terminal/src/main/java/com/stryker terminal/src/main/java/com/opxdemon
fi
if [ -d NeoTermBridge/src/main/java/com/stryker ]; then
  git mv NeoTermBridge/src/main/java/com/stryker NeoTermBridge/src/main/java/com/opxdemon
fi

# 5) Rename the rebranded class files + OTA manifest.
git mv app/src/main/java/com/opxdemon/OPXDemonApp.java app/src/main/java/com/opxdemon/OPXDemonApp.java
git mv app/src/main/java/com/opxdemon/ota/OPXDemonEndpoints.java app/src/main/java/com/opxdemon/ota/OPXDemonEndpoints.java
git mv opxdemon_manifest.json opxdemon_manifest.json

echo "=== DONE. Remaining case-insensitive 'stryker' occurrences (should be the preserved list only) ==="
grep -rni 'stryker' app/src/main terminal/src NeoLang/src NeoTermBridge/src Xorg/src chrome-tabs/src README.md THIRD-PARTY-NOTICES.md opxdemon_manifest.json *.gradle gradle.properties 2>/dev/null \
  | grep -v -i -E 'github\.com/zalexdev|/data/local/stryker|/sdcard/Stryker|stryker-guest-core|"stryker"|\.stryker-|stryker_profile|assets/stryker|files/stryker' | head -40
