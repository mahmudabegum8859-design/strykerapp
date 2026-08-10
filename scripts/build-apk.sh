#!/bin/sh
# build-apk.sh — Freebuff preview build command for OPXdemon.
#
# Produces the debug APK at app/build/outputs/apk/debug/app-debug.apk.
# Mirrors the memory-safe flags used by serve-apk.sh / setup-android.sh so the
# build does not get OOM-killed in sandboxed containers.
set -e

# Sandbox cgroup RAM cap is 2 GiB: Gradle JVM + Kotlin daemon + clang must fit
# together, so keep the profile tight and serialize native compilation.
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-1}"

echo "[build-apk] Assembling debug APK (assembleDebug)..."
sh ./gradlew --no-daemon assembleDebug \
  -Dorg.gradle.jvmargs="-Xmx768m -XX:MaxMetaspaceSize=384m -XX:+UseParallelGC" \
  -Pkotlin.daemon.jvmargs="-Xmx512m" \
  --max-workers=1

APK="app/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$APK" ]; then
  echo "[build-apk] ERROR: build did not produce $APK" >&2
  exit 1
fi

echo "[build-apk] Done: $APK"
ls -lh "$APK"
