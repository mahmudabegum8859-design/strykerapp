#!/bin/sh
# fix-package-round2.sh — catch package renames in files the first pass missed
# (C/AIDL/extension-less assets) and move leftover com/stryker source dirs.
set -e
cd "$(dirname "$0")/.."

# Content fixes for any text file still carrying the old package names.
FILES=$(grep -rlI -e 'com\.zalexdev\.stryker' -e 'com\.stryker' . 2>/dev/null \
  | grep -v '/\.git/' | grep -v '/build/' | grep -v '/\.gradle/' || true)
if [ -n "$FILES" ]; then
  perl -pi -e '
    s/com\.zalexdev\.stryker/com.opxdemon/g;
    s/com\.stryker\.terminal\.bridge/com.opxdemon.terminal.bridge/g;
    s/com\.stryker\.terminal/com.opxdemon.terminal/g;
    s/com\.stryker/com.opxdemon/g;
  ' $FILES
fi

# Move any source dirs still at the old package path.
if [ -d Xorg/src/main/java/com/stryker ]; then
  git mv Xorg/src/main/java/com/stryker Xorg/src/main/java/com/opxdemon
fi
if [ -d Xorg/src/test/java/com/stryker ]; then
  git mv Xorg/src/test/java/com/stryker Xorg/src/test/java/com/opxdemon
fi
if [ -d NeoTermBridge/src/main/aidl/com/stryker ]; then
  git mv NeoTermBridge/src/main/aidl/com/stryker NeoTermBridge/src/main/aidl/com/opxdemon
fi

echo "=== remaining old-package refs (should be none) ==="
grep -rnI 'com\.zalexdev\.stryker\|com\.stryker' app/src terminal/src NeoTermBridge/src Xorg/src chrome-tabs/src NeoLang/src 2>/dev/null | head -5 || echo none
echo "=== remaining com/stryker dirs (should be none) ==="
find . -type d -path '*/com/stryker*' -not -path '*/.git/*' -not -path '*/build/*' 2>/dev/null | head -5 || echo none
