#!/bin/sh
cd /home/daytona/codebase || exit 1
cmp /tmp/oa/usr/local/sbin/stryker-agentd /tmp/na/usr/local/sbin/stryker-agentd && echo 'agentd: identical'
cmp /tmp/oa/usr/local/sbin/stryker-ptyd /tmp/na/usr/local/sbin/stryker-ptyd && echo 'ptyd: identical'
cmp /tmp/oa/CORE/PixieWps/pixie.py /tmp/na/CORE/PixieWps/pixie.py && echo 'pixie: identical (unexpected)' || echo 'pixie: intentionally different (tags rebranded)'
df -h / | tail -1
