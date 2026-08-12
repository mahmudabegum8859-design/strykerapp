#!/bin/sh
# build-qemu-android.sh — cross-build QEMU 11.0.2 system emulators for the
# aarch64 Android host using the Android NDK (bionic libc), with:
#   * libusb enabled (USB device passthrough)
#   * USBDEVFS_GET_SPEED ioctl fix (scripts/qemu-usb-host-speed.patch)
# Targets: arm-softmmu, i386-softmmu, x86_64-softmmu, aarch64-softmmu.
#
# Why bionic and not musl-static: the previous musl-static QEMU exits with
# code 159 (SIGSYS) on Android — the app sandbox seccomp policy blocks a
# syscall the musl runtime issues directly. Bionic-linked binaries run under
# the policy, exactly like the original zalexdev qemu-system-aarch64
# (NEEDED: libc/libz/libm/libdl/libslirp). We keep linking the same shared
# libslirp.so (v4.7.0) that ships in the core-files release.
#
# Logs: /tmp/qemu-android-build.log
set -x
exec > /tmp/qemu-android-build.log 2>&1
export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

NDK=/home/daytona/android-sdk/ndk/25.1.8937393
TC=$NDK/toolchains/llvm/prebuilt/linux-x86_64
export PATH="/opt/android/bin:$TC/bin:$PATH"

# Prefix for our static dependency builds (glib, pixman, zlib, libusb)
PREFIX=/opt/android
mkdir -p "$PREFIX/src" "$PREFIX/stage/lib/pkgconfig"
HOST=aarch64-linux-android28
CC="$TC/bin/${HOST}-clang"
AR="$TC/bin/llvm-ar"
RANLIB="$TC/bin/llvm-ranlib"
NM="$TC/bin/llvm-nm"
CFLAGS="-Os -fPIC -I$PREFIX/stage/include"
LDFLAGS="-L$PREFIX/stage/lib"

echo "START $(date)"

# ---- cross pkg-config wrapper ----
cat > "$PREFIX/${HOST}-pkg-config" <<EOF
#!/bin/sh
export PKG_CONFIG_LIBDIR="$PREFIX/stage/lib/pkgconfig"
export PKG_CONFIG_PATH=
exec pkg-config --define-prefix "\$@"
EOF
chmod +x "$PREFIX/${HOST}-pkg-config"

# ---- meson cross file ----
cat > "$PREFIX/cross-bionic.txt" <<EOF
[binaries]
c = '$CC'
cpp = '$TC/bin/${HOST}-clang++'
ar = '$AR'
ranlib = '$RANLIB'
nm = '$NM'
pkgconfig = '$PREFIX/${HOST}-pkg-config'
strip = '$TC/bin/llvm-strip'

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF

# ---- 1) zlib (static) ----
if [ -f "$PREFIX/stage/lib/libz.a" ]; then
  echo "zlib already built — skipping"
else
  cd "$PREFIX/src" || exit 1
  rm -rf zlib-1.3.1
  curl -fsSL -o zlib.tar.gz https://zlib.net/fossils/zlib-1.3.1.tar.gz || { echo "zlib dl FAIL"; exit 1; }
  tar xzf zlib.tar.gz && rm -f zlib.tar.gz
  cd zlib-1.3.1
  CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS" \
    ./configure --static --prefix="$PREFIX/stage" > /tmp/azlib.cfg.log 2>&1 \
    || { echo "zlib configure FAIL"; tail -10 /tmp/azlib.cfg.log; exit 1; }
  make -j8 > /tmp/azlib.make.log 2>&1 || { echo "zlib make FAIL"; tail -10 /tmp/azlib.make.log; exit 1; }
  make install > /dev/null 2>&1 || { echo "zlib install FAIL"; exit 1; }
  echo "zlib OK $(date)"
fi

# ---- 2) libffi (static) ----
if [ -f "$PREFIX/stage/lib/libffi.a" ]; then
  echo "libffi already built — skipping"
else
  cd "$PREFIX/src" || exit 1
  rm -rf libffi-3.4.6
  curl -fsSL -o ffi.tar.gz https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz || { echo "ffi dl FAIL"; exit 1; }
  tar xzf ffi.tar.gz && rm -f ffi.tar.gz
  cd libffi-3.4.6
  ./configure --host=$HOST --prefix="$PREFIX/stage" --enable-static --disable-shared \
    --disable-docs CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" CC="$CC" \
    > /tmp/affi.cfg.log 2>&1 || { echo "ffi configure FAIL"; tail -10 /tmp/affi.cfg.log; exit 1; }
  make -j8 > /tmp/affi.make.log 2>&1 || { echo "ffi make FAIL"; tail -10 /tmp/affi.make.log; exit 1; }
  make install > /dev/null 2>&1 || { echo "ffi install FAIL"; exit 1; }
  echo "libffi OK $(date)"
fi

# ---- 3) pcre2 (static) ----
if [ -f "$PREFIX/stage/lib/libpcre2-8.a" ]; then
  echo "pcre2 already built — skipping"
else
  cd "$PREFIX/src" || exit 1
  rm -rf pcre2-10.44
  curl -fsSL -o pcre2.tar.gz https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.44/pcre2-10.44.tar.gz || { echo "pcre2 dl FAIL"; exit 1; }
  tar xzf pcre2.tar.gz && rm -f pcre2.tar.gz
  cd pcre2-10.44
  ./configure --host=$HOST --prefix="$PREFIX/stage" --enable-static --disable-shared \
    --disable-jit --disable-pcre2grep-callout CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" CC="$CC" \
    > /tmp/apcre2.cfg.log 2>&1 || { echo "pcre2 configure FAIL"; tail -10 /tmp/apcre2.cfg.log; exit 1; }
  make -j8 > /tmp/apcre2.make.log 2>&1 || { echo "pcre2 make FAIL"; tail -10 /tmp/apcre2.make.log; exit 1; }
  make install > /dev/null 2>&1 || { echo "pcre2 install FAIL"; exit 1; }
  echo "pcre2 OK $(date)"
fi

# ---- 4) pixman (static, meson) ----
if [ -f "$PREFIX/stage/lib/libpixman-1.a" ]; then
  echo "pixman already built — skipping"
else
  cd "$PREFIX/src" || exit 1
  rm -rf pixman-0.44.2
  curl -fsSL -o pixman.tar.gz https://www.cairographics.org/releases/pixman-0.44.2.tar.gz || { echo "pixman dl FAIL"; exit 1; }
  tar xzf pixman.tar.gz && rm -f pixman.tar.gz
  cd pixman-0.44.2
  PKG_CONFIG="$PREFIX/${HOST}-pkg-config" \
    meson setup build --cross-file="$PREFIX/cross-bionic.txt" \
    -Dtests=disabled -Dgtk=disabled -Ddefault_library=static \
    --prefix="$PREFIX/stage" > /tmp/apixman.meson.log 2>&1 \
    || { echo "pixman meson FAIL"; tail -15 /tmp/apixman.meson.log; exit 1; }
  ninja -C build > /tmp/apixman.ninja.log 2>&1 || { echo "pixman ninja FAIL"; tail -10 /tmp/apixman.ninja.log; exit 1; }
  ninja -C build install > /dev/null 2>&1 || { echo "pixman install FAIL"; exit 1; }
  echo "pixman OK $(date)"
fi

# ---- 5) glib (static, meson) ----
if [ -f "$PREFIX/stage/lib/libglib-2.0.a" ]; then
  echo "glib already built — skipping"
elif [ -d "$PREFIX/src/glib-2.80.4/build" ]; then
  echo "glib partially built — resuming ninja"
  cd "$PREFIX/src/glib-2.80.4" || exit 1
  ninja -C build > /tmp/aglib.ninja.log 2>&1 || { echo "glib ninja FAIL"; tail -15 /tmp/aglib.ninja.log; exit 1; }
  ninja -C build install > /dev/null 2>&1 || { echo "glib install FAIL"; exit 1; }
  echo "glib OK $(date)"
else
  cd "$PREFIX/src" || exit 1
  curl -fsSL -o glib.tar.xz https://download.gnome.org/sources/glib/2.80/glib-2.80.4.tar.xz || { echo "glib dl FAIL"; exit 1; }
  tar xJf glib.tar.xz && rm -f glib.tar.xz
  cd glib-2.80.4
  PKG_CONFIG="$PREFIX/${HOST}-pkg-config" \
    meson setup build --cross-file="$PREFIX/cross-bionic.txt" \
    -Dlibmount=disabled -Dtests=false -Dnls=disabled -Dselinux=disabled -Dxattr=false \
    -Dman-pages=disabled -Ddtrace=false -Ddocumentation=false -Dintrospection=disabled \
    -Dlibelf=disabled -Ddefault_library=static \
    --prefix="$PREFIX/stage" > /tmp/aglib.meson.log 2>&1 \
    || { echo "glib meson FAIL"; tail -20 /tmp/aglib.meson.log; exit 1; }
  ninja -C build > /tmp/aglib.ninja.log 2>&1 || { echo "glib ninja FAIL"; tail -15 /tmp/aglib.ninja.log; exit 1; }
  ninja -C build install > /dev/null 2>&1 || { echo "glib install FAIL"; exit 1; }
  echo "glib OK $(date)"
fi

# ---- 6) libusb (static) — USB host device passthrough ----
if [ -f "$PREFIX/stage/lib/libusb-1.0.a" ]; then
  echo "libusb already built — skipping"
else
  cd "$PREFIX/src" || exit 1
  rm -rf libusb-1.0.28 libusb.tar.bz2
  curl -fsSL -o libusb.tar.bz2 https://github.com/libusb/libusb/releases/download/v1.0.28/libusb-1.0.28.tar.bz2 || { echo "libusb dl FAIL"; exit 1; }
  tar xjf libusb.tar.bz2 && rm -f libusb.tar.bz2
  cd libusb-1.0.28
  ./configure --host=$HOST --prefix="$PREFIX/stage" --enable-static --disable-shared \
    --disable-udev --disable-examples --disable-tests --disable-log \
    CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" CC="$CC" \
    > /tmp/alibusb.cfg.log 2>&1 || { echo "libusb configure FAIL"; tail -15 /tmp/alibusb.cfg.log; exit 1; }
  make -j8 > /tmp/alibusb.make.log 2>&1 || { echo "libusb make FAIL"; tail -10 /tmp/alibusb.make.log; exit 1; }
  make install > /dev/null 2>&1 || { echo "libusb install FAIL"; exit 1; }
  echo "libusb OK $(date)"
fi

# ---- 7) libslirp v4.7.0 (shared) — must ABI-match the shipped libslirp.so ----
if [ -f "$PREFIX/stage/lib/libslirp.so" ]; then
  echo "libslirp already built — skipping"
else
  cd "$PREFIX/src" || exit 1
  rm -rf libslirp-v4.7.0 libslirp.tar.gz
  curl -fsSL -o libslirp.tar.gz https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v4.7.0/libslirp-v4.7.0.tar.gz || { echo "libslirp dl FAIL"; exit 1; }
  tar xzf libslirp.tar.gz && rm -f libslirp.tar.gz
  cd libslirp-v4.7.0
  # The shipped libslirp.so has SONAME "libslirp.so" (unversioned); the
  # app links it at runtime, so build with an unversioned SONAME too.
  python3 - <<'PYEOF'
import re
p = "meson.build"
s = open(p).read()
s = s.replace("lib = library('slirp', sources,\n  version : lt_version,",
              "lib = library('slirp', sources,", 1)
open(p, "w").write(s)
PYEOF
  PKG_CONFIG="$PREFIX/${HOST}-pkg-config" \
    meson setup build --cross-file="$PREFIX/cross-bionic.txt" \
    -Ddefault_library=shared --prefix="$PREFIX/stage" > /tmp/aslirp.meson.log 2>&1 \
    || { echo "libslirp meson FAIL"; tail -15 /tmp/aslirp.meson.log; exit 1; }
  ninja -C build > /tmp/aslirp.ninja.log 2>&1 || { echo "libslirp ninja FAIL"; tail -10 /tmp/aslirp.ninja.log; exit 1; }
  ninja -C build install > /dev/null 2>&1 || { echo "libslirp install FAIL"; exit 1; }
  echo "libslirp OK $(date)"
fi

# ---- 8) QEMU 11.0.2 ----
if [ -f "$PREFIX/src/qemu-11.0.2/build/qemu-system-arm" ] \
   && [ -f "$PREFIX/src/qemu-11.0.2/build/qemu-system-i386" ] \
   && [ -f "$PREFIX/src/qemu-11.0.2/build/qemu-system-x86_64" ] \
   && [ -f "$PREFIX/src/qemu-11.0.2/build/qemu-system-aarch64" ]; then
  echo "qemu already built — skipping"
elif [ -f "$PREFIX/src/qemu-11.0.2/build/config-host.mak" ]; then
  echo "qemu partially built — resuming make"
  cd "$PREFIX/src/qemu-11.0.2" || exit 1
  make -j4 > /tmp/aqemu.make.log 2>&1 || { echo "qemu make FAIL"; tail -25 /tmp/aqemu.make.log; exit 1; }
  echo "qemu make OK $(date)"
else
  cd "$PREFIX/src" || exit 1
  rm -rf qemu-11.0.2
  curl -fsSL -o qemu.tar.xz https://download.qemu.org/qemu-11.0.2.tar.xz || { echo "qemu dl FAIL"; exit 1; }
  tar xJf qemu.tar.xz --exclude='*/roms/*' && rm -f qemu.tar.xz
  cd qemu-11.0.2
  if grep -q 'ioctl(hostfd, USBDEVFS_GET_SPEED, &usb_speed)' hw/usb/host-libusb.c; then
    echo "usb-host speed patch already applied — skipping"
  else
    patch -p1 < "$SCRIPT_DIR/qemu-usb-host-speed.patch" > /tmp/aqemu.patch.log 2>&1 \
      || { echo "usb-host patch FAIL"; tail -20 /tmp/aqemu.patch.log; exit 1; }
    echo "usb-host speed patch applied"
  fi
  PKG_CONFIG="$PREFIX/${HOST}-pkg-config" \
    ./configure --cross-prefix="${HOST}-" --cc="$CC" --cxx="$TC/bin/${HOST}-clang++" \
    --host-cc=gcc \
    --target-list=arm-softmmu,i386-softmmu,x86_64-softmmu,aarch64-softmmu \
    --enable-slirp --enable-libusb \
    --disable-docs --disable-guest-agent --disable-vnc --disable-vnc-sasl \
    --disable-gnutls --disable-nettle --disable-gcrypt --disable-curses --disable-sdl --disable-gtk --disable-vte \
    --disable-usb-redir --disable-brlapi --disable-curl --disable-vhost-user-blk-server \
    --disable-vhost-crypto --disable-vhost-kernel --disable-vhost-net --disable-vhost-user --disable-vhost-vdpa \
    --disable-seccomp --disable-spice --disable-libiscsi --disable-libnfs --disable-libssh \
    --disable-lzo --disable-snappy --disable-bzip2 --disable-lzfse --disable-zstd --disable-multiprocess \
    --disable-modules --disable-mpath --disable-rbd --disable-glusterfs --disable-vduse-blk-export \
    --disable-debug-tcg \
    --extra-cflags="-Os -I$PREFIX/stage/include" --extra-ldflags="-L$PREFIX/stage/lib" \
    > /tmp/aqemu.cfg.log 2>&1 || { echo "qemu configure FAIL"; tail -25 /tmp/aqemu.cfg.log; exit 1; }
  make -j4 > /tmp/aqemu.make.log 2>&1 || { echo "qemu make FAIL"; tail -25 /tmp/aqemu.make.log; exit 1; }
  echo "qemu make OK $(date)"
fi

cd "$PREFIX/src/qemu-11.0.2/build" || exit 1
for b in qemu-system-arm qemu-system-i386 qemu-system-x86_64 qemu-system-aarch64; do
  "$TC/bin/llvm-strip" "$b" 2>/dev/null || true
done
ls -lh qemu-system-arm qemu-system-i386 qemu-system-x86_64 qemu-system-aarch64
file qemu-system-arm qemu-system-i386 qemu-system-x86_64 qemu-system-aarch64
for b in qemu-system-arm qemu-system-i386 qemu-system-x86_64 qemu-system-aarch64; do
  echo -n "$b NEEDED: "; readelf -d "$b" | grep NEEDED | tr '\n' ' '; echo
done

echo "ALL DONE $(date)"
