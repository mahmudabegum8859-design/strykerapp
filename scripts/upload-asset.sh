#!/bin/sh
# upload-asset.sh <tag> <file>
# Uploads a single asset to the release via the uploads.github.com REST API using
# gh's own authenticated client (gh release upload uses the tus resumable protocol
# which fails for large files in this sandbox; a plain POST works fine).
set -e
TAG="$1"; FILE="$2"
REPO="mahmudabegum8859-design/strykerapp"
NAME=$(basename "$FILE")
RID=$(gh api "repos/$REPO/releases/tags/$TAG" --jq .id)

echo "[upload] $NAME -> $REPO release $TAG (release id $RID)"
if ! gh api --method POST -H 'Content-Type: application/octet-stream' \
    --input "$FILE" \
    "https://uploads.github.com/repos/$REPO/releases/$RID/assets?name=$NAME" \
    > /tmp/opxrelease/up.out.json 2>/tmp/opxrelease/up.err; then
  if grep -q 'Validation Failed' /tmp/opxrelease/up.err; then
    echo "[upload] already exists on release: $NAME (skipped)"
    rm -f "$FILE"
    exit 0
  fi
  echo "[upload] FAILED: $(head -c 200 /tmp/opxrelease/up.err)"
  exit 1
fi
grep -q '"name"' /tmp/opxrelease/up.out.json || { echo "[upload] unexpected response"; exit 1; }
echo "[upload] OK: $NAME"
rm -f "$FILE"
