package com.opxdemon.ota;

import android.content.Context;

import com.opxdemon.engine.GuestArch;

public final class CoreDownloader {

    private CoreDownloader() {
    }

    /**
     * Resolves the Debian chroot archive for the rooted engine.
     * The chroot must match the device CPU architecture, so it follows the
     * device ABI rather than the selectable rootless guest architecture.
     */
    public static RemoteManifest.Asset resolve(Context context) {
        RemoteManifest manifest = ManifestService.fetch(context);
        if (manifest != null) {
            RemoteManifest.Asset deviceChroot = manifest.chrootByArch.get(deviceArchKey());
            if (deviceChroot != null && deviceChroot.isUsable()) return deviceChroot;
            if (manifest.chroot64 != null && manifest.chroot64.isUsable()) {
                return manifest.chroot64;
            }
        }
        return new RemoteManifest.Asset(OPXDemonEndpoints.FALLBACK_CHROOT_64, "", 0);
    }

    private static String deviceArchKey() {
        try {
            String abi = android.os.Build.SUPPORTED_ABIS != null
                    && android.os.Build.SUPPORTED_ABIS.length > 0
                    ? android.os.Build.SUPPORTED_ABIS[0] : "";
            if (abi != null && abi.startsWith("arm64")) return GuestArch.ARM64.key;
            if (abi != null && abi.startsWith("armeabi")) return GuestArch.ARMHF.key;
            if (abi != null && abi.startsWith("x86_64")) return GuestArch.AMD64.key;
            if (abi != null && abi.startsWith("x86")) return GuestArch.I386.key;
        } catch (Throwable ignored) {
        }
        return GuestArch.ARM64.key;
    }
}
