package com.opxdemon.engine;

/**
 * Guest architectures supported by the rootless VM engine.
 *
 * Each entry maps to a payload set published on the "chroot + rootless core files"
 * release of this repository:
 *   - arm64  (tested):  qemu-system-aarch64 + Image + initrd.img + libslirp.so + rootfs.imgz
 *   - armhf  (not tested on hardware, QEMU boot-verified):  qemu-system-arm + Image-arm + initrd-arm.img + rootfs-arm.imgz
 *   - i386   (not tested on hardware, QEMU boot-verified):  qemu-system-i386 + Image-i386 + initrd-i386.img + rootfs-i386.imgz
 *   - amd64  (not tested on hardware, QEMU boot-verified):  qemu-system-x86_64 + Image-amd64 + initrd-amd64.img + rootfs-amd64.imgz
 *
 * All four qemu-system-* binaries are bionic-linked against the shared
 * libslirp.so (NEEDED libc/libm/libdl/libslirp), so every guest architecture
 * downloads the separate libslirp.so from the release.
 */
public enum GuestArch {

    ARM64("arm64", "qemu-system-aarch64", "Image", "initrd.img", true),
    ARMHF("armhf", "qemu-system-arm", "Image-arm", "initrd-arm.img", true),
    I386("i386", "qemu-system-i386", "Image-i386", "initrd-i386.img", true),
    AMD64("amd64", "qemu-system-x86_64", "Image-amd64", "initrd-amd64.img", true);

    /** Key used in the OTA manifest, prefs and the release asset names. */
    public final String key;
    /** Release asset name of the QEMU system emulator binary. */
    public final String qemuName;
    /** Release asset name of the guest kernel image. */
    public final String kernelName;
    /** Release asset name of the guest initramfs. */
    public final String initrdName;
    /** True when this host engine binary links against the shared libslirp.so at runtime. */
    public final boolean needsLibslirp;

    GuestArch(String key, String qemuName, String kernelName, String initrdName,
              boolean needsLibslirp) {
        this.key = key;
        this.qemuName = qemuName;
        this.kernelName = kernelName;
        this.initrdName = initrdName;
        this.needsLibslirp = needsLibslirp;
    }

    public boolean isArm() {
        return this == ARM64 || this == ARMHF;
    }

    /** True when this guest uses the virtio-PCI bus (arm64 and x86 guests). */
    public boolean isPci() {
        return this != ARMHF;
    }

    public static GuestArch fromKey(String key) {
        if (key == null) return ARM64;
        for (GuestArch a : values()) {
            if (a.key.equalsIgnoreCase(key.trim())) return a;
        }
        return ARM64;
    }

    public static String[] keys() {
        GuestArch[] all = values();
        String[] keys = new String[all.length];
        for (int i = 0; i < all.length; i++) keys[i] = all[i].key;
        return keys;
    }
}
