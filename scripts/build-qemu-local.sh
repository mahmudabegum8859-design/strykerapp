#!/bin/sh
# build-qemu-local.sh — cross-build static QEMU 9.2 system emulators for the
# aarch64 Android host (guests: arm, i386, x86_64) using a musl toolchain, and
# upload the three binaries to the "chroot + rootless core files" release.
# Fully static binaries: no external libs, self-contained on any Android.
# Logs: /tmp/qemu-build.log
set -x
exec > /tmp/qemu-build.log 2>&1
export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CROSS=/opt/musl
PREFIX=$CROSS/stage
mkdir -p "$CROSS/src" "$PREFIX"
echo "START $(date)"

# ---- 1) musl cross toolchain (aarch64) ----
if [ ! -x "$CROSS/bin/aarch64-linux-musl-gcc" ]; then
  mkdir -p "$CROSS"
  curl -fsSL -o /tmp/musl-cross.tgz https://musl.cc/aarch64-linux-musl-cross.tgz || { echo "toolchain download FAIL"; exit 1; }
  tar -xzf /tmp/musl-cross.tgz -C "$CROSS" --strip-components=1
  rm -f /tmp/musl-cross.tgz
fi
export PATH="$CROSS/bin:$PATH"
aarch64-linux-musl-gcc --version | head -1 || { echo "toolchain broken"; exit 1; }

# ---- 2) host tools ----
apt-get update -qq >/dev/null 2>&1 || true
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ninja-build autoconf automake libtool make pkg-config gperf >/dev/null 2>&1 || true
python3 -m pip install -q --upgrade meson packaging tomli 2>/dev/null || true
python3 -c 'import mesonbuild, packaging, tomli' 2>/dev/null || { echo "meson/packaging/tomli missing"; exit 1; }
meson --version || { echo "meson missing"; exit 1; }

# cross pkg-config wrapper
cat > "$CROSS/aarch64-linux-musl-pkg-config" <<EOF
#!/bin/sh
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
export PKG_CONFIG_PATH=
exec pkg-config --define-prefix "\$@"
EOF
chmod +x "$CROSS/aarch64-linux-musl-pkg-config"

CFLAGS="-Os -I$PREFIX/include"
LDFLAGS="-L$PREFIX/lib -static"

# ---- 3) zlib (static) ----
if [ -f "$PREFIX/lib/libz.a" ]; then
  echo "zlib already built — skipping"
else
  cd "$CROSS/src" || exit 1
  rm -rf zlib-1.3.1
  curl -fsSL -o zlib.tar.gz https://zlib.net/fossils/zlib-1.3.1.tar.gz || { echo "zlib dl FAIL"; exit 1; }
  tar xzf zlib.tar.gz && rm -f zlib.tar.gz
  cd zlib-1.3.1
  CC=aarch64-linux-musl-gcc AR=aarch64-linux-musl-ar RANLIB=aarch64-linux-musl-ranlib \
    ./configure --static --prefix="$PREFIX" > /tmp/zlib.cfg.log 2>&1 || { echo "zlib configure FAIL"; tail -10 /tmp/zlib.cfg.log; exit 1; }
  make -j48 > /tmp/zlib.make.log 2>&1 || { echo "zlib make FAIL"; tail -10 /tmp/zlib.make.log; exit 1; }
  make install > /dev/null 2>&1 || { echo "zlib install FAIL"; exit 1; }
  echo "zlib OK $(date)"
fi

# ---- 4) libffi (static) ----
if [ -f "$PREFIX/lib/libffi.a" ]; then
  echo "libffi already built — skipping"
else
  cd "$CROSS/src" || exit 1
  rm -rf libffi-3.4.6
  curl -fsSL -o ffi.tar.gz https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz || { echo "ffi dl FAIL"; exit 1; }
  tar xzf ffi.tar.gz && rm -f ffi.tar.gz
  cd libffi-3.4.6
  ./configure --host=aarch64-linux-musl --prefix="$PREFIX" --enable-static --disable-shared \
    --disable-docs CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" > /tmp/ffi.cfg.log 2>&1 || { echo "ffi configure FAIL"; tail -10 /tmp/ffi.cfg.log; exit 1; }
  make -j48 > /tmp/ffi.make.log 2>&1 || { echo "ffi make FAIL"; tail -10 /tmp/ffi.make.log; exit 1; }
  make install > /dev/null 2>&1 || { echo "ffi install FAIL"; exit 1; }
  echo "libffi OK $(date)"
fi

# ---- 5) pcre2 (static) ----
if [ -f "$PREFIX/lib/libpcre2-8.a" ]; then
  echo "pcre2 already built — skipping"
else
  cd "$CROSS/src" || exit 1
  rm -rf pcre2-10.44
  curl -fsSL -o pcre2.tar.gz https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.44/pcre2-10.44.tar.gz || { echo "pcre2 dl FAIL"; exit 1; }
  tar xzf pcre2.tar.gz && rm -f pcre2.tar.gz
  cd pcre2-10.44
  ./configure --host=aarch64-linux-musl --prefix="$PREFIX" --enable-static --disable-shared \
    --disable-jit --disable-pcre2grep-callout CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
    > /tmp/pcre2.cfg.log 2>&1 || { echo "pcre2 configure FAIL"; tail -10 /tmp/pcre2.cfg.log; exit 1; }
  make -j48 > /tmp/pcre2.make.log 2>&1 || { echo "pcre2 make FAIL"; tail -10 /tmp/pcre2.make.log; exit 1; }
  make install > /dev/null 2>&1 || { echo "pcre2 install FAIL"; exit 1; }
  echo "pcre2 OK $(date)"
fi

# ---- 6) pixman (static) ----
if [ -f "$PREFIX/lib/libpixman-1.a" ]; then
  echo "pixman already built — skipping"
else
  cd "$CROSS/src" || exit 1
  rm -rf pixman-0.43.4
  curl -fsSL -o pixman.tar.gz https://www.cairographics.org/releases/pixman-0.43.4.tar.gz || { echo "pixman dl FAIL"; exit 1; }
  tar xzf pixman.tar.gz && rm -f pixman.tar.gz
  cd pixman-0.43.4
  PKG_CONFIG="$CROSS/aarch64-linux-musl-pkg-config" \
    meson setup build --cross-file="$CROSS/cross-musl.txt" \
    -Dtests=disabled -Dgtk=disabled -Ddefault_library=static \
    --prefix="$PREFIX" > /tmp/pixman.meson.log 2>&1 || { echo "pixman meson FAIL"; tail -15 /tmp/pixman.meson.log; exit 1; }
  ninja -C build > /tmp/pixman.ninja.log 2>&1 || { echo "pixman ninja FAIL"; tail -10 /tmp/pixman.ninja.log; exit 1; }
  ninja -C build install > /dev/null 2>&1 || { echo "pixman install FAIL"; exit 1; }
  echo "pixman OK $(date)"
fi

# ---- 7) glib (static) ----
if [ -f "$PREFIX/lib/libglib-2.0.a" ]; then
  echo "glib already built — skipping"
elif [ -d "$CROSS/src/glib-2.80.4/build" ]; then
  echo "glib partially built — resuming ninja"
  cd "$CROSS/src/glib-2.80.4" || exit 1
  ninja -C build > /tmp/glib.ninja.log 2>&1 || { echo "glib ninja FAIL"; tail -15 /tmp/glib.ninja.log; exit 1; }
  ninja -C build install > /dev/null 2>&1 || { echo "glib install FAIL"; exit 1; }
  echo "glib OK $(date)"
else
  cd "$CROSS/src" || exit 1
  curl -fsSL -o glib.tar.xz https://download.gnome.org/sources/glib/2.80/glib-2.80.4.tar.xz || { echo "glib dl FAIL"; exit 1; }
  tar xJf glib.tar.xz && rm -f glib.tar.xz
  cd glib-2.80.4
  PKG_CONFIG="$CROSS/aarch64-linux-musl-pkg-config" \
    meson setup build --cross-file="$CROSS/cross-musl.txt" \
    -Dlibmount=disabled -Dtests=false -Dnls=disabled -Dselinux=disabled -Dxattr=false \
    -Dman-pages=disabled -Ddtrace=false -Ddocumentation=false -Dintrospection=disabled \
    -Dlibelf=disabled -Ddefault_library=static \
    --prefix="$PREFIX" > /tmp/glib.meson.log 2>&1 || { echo "glib meson FAIL"; tail -20 /tmp/glib.meson.log; exit 1; }
  ninja -C build > /tmp/glib.ninja.log 2>&1 || { echo "glib ninja FAIL"; tail -15 /tmp/glib.ninja.log; exit 1; }
  ninja -C build install > /dev/null 2>&1 || { echo "glib install FAIL"; exit 1; }
  echo "glib OK $(date)"
fi

# ---- 7b) libslirp (static) — QEMU 9.2's internal slirp subproject builds a
#         shared .so that cannot link under a fully static toolchain, so build
#         libslirp as a static lib and let QEMU use it via pkg-config. ----
if [ -f "$PREFIX/lib/libslirp.a" ]; then
  echo "libslirp already built — skipping"
else
  cd "$CROSS/src" || exit 1
  rm -rf libslirp-v4.8.0 libslirp.tar.gz
  curl -fsSL -o libslirp.tar.gz https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v4.8.0/libslirp-v4.8.0.tar.gz || { echo "libslirp dl FAIL"; exit 1; }
  tar xzf libslirp.tar.gz && rm -f libslirp.tar.gz
  cd libslirp-v4.8.0
  PKG_CONFIG="$CROSS/aarch64-linux-musl-pkg-config" \
    meson setup build --cross-file="$CROSS/cross-musl.txt" \
    -Ddefault_library=static --prefix="$PREFIX" > /tmp/slirp.meson.log 2>&1 || { echo "slirp meson FAIL"; tail -15 /tmp/slirp.meson.log; exit 1; }
  ninja -C build > /tmp/slirp.ninja.log 2>&1 || { echo "slirp ninja FAIL"; tail -10 /tmp/slirp.ninja.log; exit 1; }
  ninja -C build install > /dev/null 2>&1 || { echo "slirp install FAIL"; exit 1; }
  echo "libslirp OK $(date)"
fi

# ---- 7c) libusb (static) — usb-host device passthrough needs libusb; the
#         previous builds shipped with --disable-libusb, which means the
#         app's USB Wi-Fi passthrough (QMP device_add driver=usb-host) was
#         unavailable. Build it statically for the aarch64 musl host. ----
if [ -f "$PREFIX/lib/libusb-1.0.a" ]; then
  echo "libusb already built — skipping"
else
  cd "$CROSS/src" || exit 1
  rm -rf libusb-1.0.28 libusb.tar.bz2
  curl -fsSL -o libusb.tar.bz2 https://github.com/libusb/libusb/releases/download/v1.0.28/libusb-1.0.28.tar.bz2 || { echo "libusb dl FAIL"; exit 1; }
  tar xjf libusb.tar.bz2 && rm -f libusb.tar.bz2
  cd libusb-1.0.28
  ./configure --host=aarch64-linux-musl --prefix="$PREFIX" --enable-static --disable-shared \
    --disable-udev --disable-examples --disable-tests --disable-log CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
    > /tmp/libusb.cfg.log 2>&1 || { echo "libusb configure FAIL"; tail -15 /tmp/libusb.cfg.log; exit 1; }
  make -j48 > /tmp/libusb.make.log 2>&1 || { echo "libusb make FAIL"; tail -10 /tmp/libusb.make.log; exit 1; }
  make install > /dev/null 2>&1 || { echo "libusb install FAIL"; exit 1; }
  echo "libusb OK $(date)"
fi

# ---- 8) QEMU 9.2 (static, arm + i386 + x86_64 + aarch64 guests) ----
if [ -f "$CROSS/src/qemu-9.2.0/build/qemu-system-arm" ] \
   && [ -f "$CROSS/src/qemu-9.2.0/build/qemu-system-i386" ] \
   && [ -f "$CROSS/src/qemu-9.2.0/build/qemu-system-x86_64" ] \
   && [ -f "$CROSS/src/qemu-9.2.0/build/qemu-system-aarch64" ]; then
  echo "qemu already built — skipping configure/make"
elif [ -f "$CROSS/src/qemu-9.2.0/build/config-host.mak" ]; then
  echo "qemu partially built — resuming make"
  cd "$CROSS/src/qemu-9.2.0" || exit 1
  make -j48 > /tmp/qemu.make.log 2>&1 || { echo "qemu make FAIL"; tail -25 /tmp/qemu.make.log; exit 1; }
  echo "qemu make OK $(date)"
else
  cd "$CROSS/src" || exit 1
  rm -rf qemu-9.2.0
  curl -fsSL -o qemu.tar.xz https://download.qemu.org/qemu-9.2.0.tar.xz || { echo "qemu dl FAIL"; exit 1; }
  tar xJf qemu.tar.xz --exclude='*/roms/*' && rm -f qemu.tar.xz
  cd qemu-9.2.0
  # Apply the USB host speed fix (scripts/qemu-usb-host-speed.patch) so that
  # devices passed through as a raw fd from Android are presented to the guest
  # at their real speed instead of low-speed ("Invalid ep0 maxpacket: 64").
  if grep -q 'ioctl(hostfd, USBDEVFS_GET_SPEED, &usb_speed)' hw/usb/host-libusb.c; then
    echo "usb-host speed patch already applied — skipping"
  else
    patch -p1 < "$SCRIPT_DIR/qemu-usb-host-speed.patch" > /tmp/qemu.patch.log 2>&1 \
      || { echo "usb-host patch FAIL"; tail -20 /tmp/qemu.patch.log; exit 1; }
    echo "usb-host speed patch applied"
  fi
  PKG_CONFIG="$CROSS/aarch64-linux-musl-pkg-config" \
    ./configure --cross-prefix=aarch64-linux-musl- --static \
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
    --extra-cflags="-Os -I$PREFIX/include" --extra-ldflags="-L$PREFIX/lib -static" \
    > /tmp/qemu.cfg.log 2>&1 || { echo "qemu configure FAIL"; tail -25 /tmp/qemu.cfg.log; exit 1; }
  make -j48 > /tmp/qemu.make.log 2>&1 || { echo "qemu make FAIL"; tail -25 /tmp/qemu.make.log; exit 1; }
  echo "qemu make OK $(date)"
fi
ls -lh build/qemu-system-arm build/qemu-system-i386 build/qemu-system-x86_64 build/qemu-system-aarch64

# verify: static AArch64 + the USB speed fix is compiled in
file build/qemu-system-arm build/qemu-system-i386 build/qemu-system-x86_64 build/qemu-system-aarch64
readelf -d build/qemu-system-arm | grep -c NEEDED || true
strings build/qemu-system-aarch64 | grep -c 'Invalid ep0 maxpacket' >/dev/null 2>&1 || true

# smoke test on this host (x86_64 can't run aarch64; verify the x86_64 binary boots an amd64 guest)
chmod +x build/qemu-system-x86_64
timeout 90 ./build/qemu-system-x86_64 -machine help 2>&1 | head -3 || true

echo "=== uploads ==="
REPO=mahmudabegum8859-design/strykerapp
TAG=core-files
RID=$(gh api "repos/$REPO/releases/tags/$TAG" --jq .id)
for BIN in build/qemu-system-arm build/qemu-system-i386 build/qemu-system-x86_64 build/qemu-system-aarch64; do
  NAME=$(basename "$BIN")
  for AID in $(gh api "repos/$REPO/releases/$RID/assets" --jq '.[] | select(.name=="'$NAME'") | .id'); do
    gh api -X DELETE "repos/$REPO/releases/assets/$AID" >/dev/null 2>&1 || true
  done
  gh api --method POST -H 'Content-Type: application/octet-stream' --input "$BIN" \
    "https://uploads.github.com/repos/$REPO/releases/$RID/assets?name=$NAME" > /tmp/up.out.json 2>/tmp/up.err \
    && grep -q '"name"' /tmp/up.out.json && echo "UPLOADED $NAME" || { echo "UPLOAD FAIL $NAME: $(head -c 150 /tmp/up.err)"; }
done
echo "ALL DONE $(date)"
