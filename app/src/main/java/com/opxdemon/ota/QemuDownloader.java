package com.opxdemon.ota;

import android.content.Context;

import com.opxdemon.engine.GuestArch;
import com.opxdemon.engine.RootlessPaths;

public final class QemuDownloader {

    private QemuDownloader() {}

    public static final class Bundle {
        public final RemoteManifest.Asset qemu;
        public final RemoteManifest.Asset kernel;
        public final RemoteManifest.Asset initrd;
        public final RemoteManifest.Asset libslirp;
        public final RemoteManifest.Asset rootfs;

        Bundle(RemoteManifest.Asset qemu, RemoteManifest.Asset kernel, RemoteManifest.Asset initrd,
               RemoteManifest.Asset libslirp, RemoteManifest.Asset rootfs) {
            this.qemu = qemu;
            this.kernel = kernel;
            this.initrd = initrd;
            this.libslirp = libslirp;
            this.rootfs = rootfs;
        }

        public boolean isUsable() {
            return qemu != null && qemu.isUsable()
                    && kernel != null && kernel.isUsable()
                    && initrd != null && initrd.isUsable()
                    && rootfs != null && rootfs.isUsable();
        }
    }

    /** Resolves the payload bundle for the currently selected guest architecture. */
    public static Bundle resolve(Context context) {
        return resolve(context, RootlessPaths.arch(context));
    }

    public static Bundle resolve(Context context, GuestArch arch) {
        RemoteManifest manifest = ManifestService.fetch(context);
        if (manifest != null) {
            RemoteManifest.RootlessAssets r = manifest.rootlessByArch.get(arch.key);
            if (r == null && arch == GuestArch.ARM64) {
                r = manifest.rootless; // legacy flat group (v1.1/v1.2 manifest format)
            }
            if (r != null) {
                Bundle b = new Bundle(r.qemu, r.kernel, r.initrd, r.libslirp, r.rootfs);
                if (b.isUsable()) return b;
            }
        }
        return fallback(arch);
    }

    private static Bundle fallback(GuestArch arch) {
        if (arch == GuestArch.ARM64) {
            return new Bundle(
                    new RemoteManifest.Asset(OPXDemonEndpoints.FALLBACK_ROOTLESS_QEMU, "", 0),
                    new RemoteManifest.Asset(OPXDemonEndpoints.FALLBACK_ROOTLESS_KERNEL, "", 0),
                    new RemoteManifest.Asset(OPXDemonEndpoints.FALLBACK_ROOTLESS_INITRD, "", 0),
                    new RemoteManifest.Asset(OPXDemonEndpoints.FALLBACK_ROOTLESS_LIBSLIRP, "", 0),
                    new RemoteManifest.Asset(OPXDemonEndpoints.FALLBACK_ROOTLESS_ROOTFS, "", 0));
        }
        String base = OPXDemonEndpoints.RELEASE_BASE;
        return new Bundle(
                new RemoteManifest.Asset(base + arch.qemuName, "", 0),
                new RemoteManifest.Asset(base + arch.kernelName, "", 0),
                new RemoteManifest.Asset(base + arch.initrdName, "", 0),
                new RemoteManifest.Asset(base + "libslirp.so", "", 0),
                new RemoteManifest.Asset(base + "rootfs-" + arch.key + ".imgz", "", 0));
    }
}
