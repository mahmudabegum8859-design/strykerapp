#!/bin/sh
# setup-android.sh — one-time Android toolchain setup for building OPXdemon.
#
# Mirrors .github/workflows/android.yml:
#   JDK 17 + platforms;android-33 + build-tools;34.0.0 + ndk;25.1.8937393 + cmake;3.22.1
#
# Requires: root (for apt-get), ~2.5 GB free disk, network access to dl.google.com.
# Idempotent: safe to re-run; already-installed pieces are skipped.
set -e

# Sandboxes are often memory-limited: cap C/C++ build parallelism (Ninja/CMake
# would otherwise spawn one job per CPU core and get OOM-killed).
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-2}"

echo "[setup-android] == JDK 17 =="
if ! command -v java >/dev/null 2>&1 || ! java -version 2>&1 | grep -q '"17\.'; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openjdk-17-jdk-headless unzip
else
  echo "[setup-android] JDK 17 already present"
fi

export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
mkdir -p "$ANDROID_HOME/cmdline-tools"

echo "[setup-android] == Android command-line tools -> $ANDROID_HOME =="
if [ ! -x "$SDKMANAGER" ]; then
  curl -fsSL -o /tmp/cmdtools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  unzip -q -o /tmp/cmdtools.zip -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
else
  echo "[setup-android] cmdline-tools already present"
fi

echo "[setup-android] == Accepting SDK licenses =="
yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true

echo "[setup-android] == Installing SDK components (platform 33, build-tools 34, NDK 25.1.8937393, CMake 3.22.1) =="
"$SDKMANAGER" --install "platforms;android-33" "build-tools;34.0.0" "ndk;25.1.8937393" "cmake;3.22.1"

# Point AGP at the SDK. local.properties is gitignored.
echo "sdk.dir=$ANDROID_HOME" > local.properties
echo "[setup-android] Wrote local.properties: sdk.dir=$ANDROID_HOME"

echo "[setup-android] == Warming up Gradle 8.5 + AGP/Kotlin plugin resolution =="
# Memory-safe flags: the project default (-Xmx4608m) exceeds container limits.
sh ./gradlew --no-daemon help -q \
  -Dorg.gradle.jvmargs="-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:+UseParallelGC" \
  -Pkotlin.daemon.jvmargs="-Xmx1024m" \
  --max-workers=2

echo "[setup-android] Done. Toolchain ready — build with: sh ./gradlew --no-daemon assembleDebug"
