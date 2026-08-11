#!/bin/sh
cd /home/daytona/codebase || exit 1

echo '=== git original tar size vs rebuilt ==='
git show HEAD:app/src/main/assets/rootless/stryker-guest-core.tar | wc -c
ls -la app/src/main/assets/rootless/opxdemon-guest-core.tar | awk '{print "rebuilt:", $5}'
echo '--- entry count diff ---'
git show HEAD:app/src/main/assets/rootless/stryker-guest-core.tar > /tmp/orig.tar
tar -tf /tmp/orig.tar | sort > /tmp/orig.list
tar -tf app/src/main/assets/rootless/opxdemon-guest-core.tar | sort > /tmp/new.list
diff /tmp/orig.list /tmp/new.list && echo 'ENTRY LISTS IDENTICAL'
echo '--- agentd content identical? ---'
mkdir -p /tmp/oa && tar -xf /tmp/orig.tar -C /tmp/oa
mkdir -p /tmp/na && tar -xf app/src/main/assets/rootless/opxdemon-guest-core.tar -C /tmp/na
diff <(md5sum /tmp/oa/usr/local/sbin/stryker-agentd | awk '{print $1}') <(md5sum /tmp/na/usr/local/sbin/stryker-agentd | awk '{print $1}') && echo 'agentd identical'
diff <(md5sum /tmp/oa/usr/local/sbin/stryker-ptyd | awk '{print $1}') <(md5sum /tmp/na/usr/local/sbin/stryker-ptyd | awk '{print $1}') && echo 'ptyd identical'

echo
echo '=== Neighbours native declaration ==='
grep -rn 'nativeDump\|class Neighbours\|native ' app/src/main/java/com/opxdemon/localnetwork/nonroot/Neighbours.java 2>/dev/null | head -4

echo
echo '=== changed files vs git HEAD (name/status) ==='
git status --short | awk '{print $1, $2}' | head -90

echo
echo '=== disk ==='
df -h / | tail -1
