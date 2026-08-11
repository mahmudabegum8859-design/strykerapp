package com.opxdemon.ota;

public final class OPXDemonEndpoints {

    public static final String GITHUB_REPO = "https://github.com/mahmudabegum8859-design/strykerapp";

    public static final String MANIFEST_URL =
            "https://raw.githubusercontent.com/mahmudabegum8859-design/strykerapp/main/opxdemon_manifest.json";

    /** All payloads live on the "chroot + rootless core files" release. */
    public static final String RELEASE_TAG = "core-files";
    public static final String RELEASE_BASE =
            "https://github.com/mahmudabegum8859-design/strykerapp/releases/download/" + RELEASE_TAG + "/";

    public static final String FALLBACK_CHROOT_64 = RELEASE_BASE + "chroot64-debian.tar.gz";

    private static final String ROOTLESS_BASE = RELEASE_BASE;
    public static final String FALLBACK_ROOTLESS_QEMU     = ROOTLESS_BASE + "qemu-system-aarch64";
    public static final String FALLBACK_ROOTLESS_KERNEL   = ROOTLESS_BASE + "Image";
    public static final String FALLBACK_ROOTLESS_LIBSLIRP = ROOTLESS_BASE + "libslirp.so";
    public static final String FALLBACK_ROOTLESS_INITRD   = ROOTLESS_BASE + "initrd.img";
    public static final String FALLBACK_ROOTLESS_ROOTFS   = ROOTLESS_BASE + "rootfs.imgz";

    public static final String PREFS = "opxdemon_ota";

    private OPXDemonEndpoints() {
    }
}
