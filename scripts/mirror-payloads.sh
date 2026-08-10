#!/bin/sh
# mirror-payloads.sh — download remaining chroot-main payloads, verify sha256
# where known, upload to the v1.1 release, then delete the local copy.
set -e
BASE="https://github.com/zalexdev/strykerapp/releases/download/chroot-main"
TAG="v1.1"
cd /home/daytona/codebase

upload_one() {
  NAME="$1"; WANT="$2"
  echo "--- $NAME ---"
  curl -fsSL -o "/tmp/opxrelease/$NAME" "$BASE/$NAME" || { echo "FAIL download $NAME"; exit 1; }
  if [ -n "$WANT" ]; then
    GOT=$(sha256sum "/tmp/opxrelease/$NAME" | cut -d' ' -f1)
    if [ "$GOT" != "$WANT" ]; then echo "SHA MISMATCH $NAME"; exit 1; fi
    echo "sha OK: $NAME"
  fi
  sh ./scripts/upload-asset.sh "$TAG" "/tmp/opxrelease/$NAME"
}

upload_one chroot64.tar.gz     2ad21f1445102913c52099bcb86ab380f9520c9e4d7771e6a951f634451068ac
upload_one chroot32.tar.gz     faa4b256819818360945d8fecc8f05f0f158a76e6a61feb8eff66308c32b3341
upload_one chroot_v5b_64.tar.gz
upload_one 4.0.tar.gz
