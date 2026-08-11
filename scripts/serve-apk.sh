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

# Small index page with a direct download link.
cat > "$APK_DIR/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>OPXdemon — APK download</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; background: #0f1115; color: #e6e8ee;
           display: grid; place-items: center; min-height: 100vh; margin: 0; }
    .card { max-width: 520px; padding: 2.5rem; border: 1px solid #262b36; border-radius: 16px;
            background: #161a22; text-align: center; }
    h1 { margin: 0 0 .5rem; font-size: 1.4rem; }
    p { color: #9aa3b2; margin: 0 0 1.5rem; font-size: .95rem; }
    a.dl { display: inline-block; background: #e11d48; color: #fff; text-decoration: none;
           padding: .8rem 1.6rem; border-radius: 10px; font-weight: 600; }
    a.dl:hover { background: #f0305a; }
    code { background: #0f1115; padding: .25rem .5rem; border-radius: 6px; font-size: .8rem; }
    .meta { margin-top: 1.5rem; font-size: .8rem; color: #6b7280; }
  </style>
</head>
<body>
  <div class="card">
    <h1>OPXdemon 1.2 — debug build</h1>
    <p>Output of <code>./gradlew assembleDebug</code>. Download the APK and sideload it
       on a <strong>rooted</strong> arm64 Android device (min SDK 24).</p>
    <a class="dl" href="app-debug.apk" download>Download app-debug.apk</a>
    <p class="meta">Package com.opxdemon · versionCode 2 · GPLv3</p>
  </div>
</body>
</html>
HTML

echo "[serve-apk] Serving $APK_DIR on 0.0.0.0:$PORT (APK: $APK)"
if command -v python3 >/dev/null 2>&1; then
  exec python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$APK_DIR"
fi
echo "[serve-apk] python3 not found — falling back to npx serve"
exec npx --yes serve -l "tcp://0.0.0.0:$PORT" "$APK_DIR"
