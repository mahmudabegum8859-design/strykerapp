#!/bin/sh
# serve-apk.sh — Freebuff preview (dev) command for OPXdemon.
#
# Builds the debug APK on first run, then serves the output directory on
# 0.0.0.0:$PORT so the APK can be downloaded from the preview pane.
# $PORT is injected by Freebuff for isolated workspaces.
set -e

PORT="${PORT:-3000}"
APK_DIR="app/build/outputs/apk/debug"
APK="$APK_DIR/app-debug.apk"

# Sandbox cgroup RAM cap is 2 GiB: Gradle JVM + Kotlin daemon + clang must fit
# together, so keep the profile tight and serialize native compilation.
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-1}"

if [ ! -f "$APK" ]; then
  echo "[serve-apk] No APK found — building debug APK..."
  # Memory-safe flags: the project default (-Xmx4608m) exceeds container limits.
  sh ./gradlew --no-daemon assembleDebug \
    -Dorg.gradle.jvmargs="-Xmx768m -XX:MaxMetaspaceSize=384m -XX:+UseParallelGC" \
    -Pkotlin.daemon.jvmargs="-Xmx512m" \
    --max-workers=1
fi

if [ ! -f "$APK" ]; then
  echo "[serve-apk] ERROR: build did not produce $APK" >&2
  exit 1
fi

# Professional landing/download page (auto-detects the latest release from GitHub).
SITE="site/index.html"
if [ -f "$SITE" ]; then
  cp "$SITE" "$APK_DIR/index.html"
  echo "[serve-apk] Serving site/index.html (auto-detects latest GitHub release)"
else
  echo "[serve-apk] WARNING: $SITE missing — fallback page without styling"
  printf '<!doctype html><meta charset="utf-8"><title>OPXdemon</title><h1>OPXdemon</h1><p><a href="app-debug.apk">Download app-debug.apk</a></p>' > "$APK_DIR/index.html"
fi

echo "[serve-apk] Serving $APK_DIR on 0.0.0.0:$PORT (APK: $APK)"
if command -v python3 >/dev/null 2>&1; then
  exec python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$APK_DIR"
fi
echo "[serve-apk] python3 not found — falling back to npx serve"
exec npx --yes serve -l "tcp://0.0.0.0:$PORT" "$APK_DIR"
