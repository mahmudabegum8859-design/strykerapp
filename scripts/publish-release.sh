#!/bin/sh
# publish-release.sh <tag> <filename> <download-url> [sha256]
# Downloads a payload, verifies its sha256 (when given), uploads it to the
# release on this repo, then deletes the local copy to keep disk usage flat.
set -e
TAG="$1"; NAME="$2"; URL="$3"; WANT="$4"
REPO="mahmudabegum8859-design/strykerapp"
DIR=/tmp/opxrelease
mkdir -p "$DIR"
LOCAL="$DIR/$NAME"

if [ ! -f "$LOCAL" ]; then
  echo "[publish] downloading $NAME ..."
  curl -fsSL -o "$LOCAL" "$URL" || { echo "[publish] DOWNLOAD FAILED: $NAME"; exit 1; }
fi

if [ -n "$WANT" ]; then
  GOT=$(sha256sum "$LOCAL" | cut -d' ' -f1)
  if [ "$GOT" != "$WANT" ]; then
    echo "[publish] SHA MISMATCH $NAME: got $GOT want $WANT"
    exit 1
  fi
  echo "[publish] sha256 OK: $NAME"
fi

echo "[publish] uploading $NAME ($(du -h "$LOCAL" | cut -f1)) ..."
if ! OUT=$(gh release upload "$TAG" -R "$REPO" "$LOCAL" --clobber 2>&1); then
  echo "[publish] UPLOAD FAILED: $NAME"
  echo "$OUT" | tail -3
  echo "[publish] keeping local copy for retry: $LOCAL"
  exit 1
fi
rm -f "$LOCAL"
echo "[publish] done: $NAME"
