package com.opxdemon.ota;

import android.content.Context;

import org.json.JSONObject;

/**
 * Remembers which payload version the rootless engine was installed from.
 *
 * The engine's smaller files (qemu, kernel, initrd, libslirp) are verified on
 * every start by hashing the on-disk file and comparing it with the manifest's
 * sha256, so they need no stored state. The rootfs is stored DECOMPRESSED
 * (rootfs.img) while the manifest checksums the COMPRESSED archive
 * (rootfs.imgz), so we cannot hash the local file to detect changes. Instead
 * the manifest sha256 of the rootfs archive is recorded here at install time
 * and compared against the current manifest whenever the engine starts.
 */
public final class PayloadState {

    public static final String KEY_ROOTFS_SHA = "payload_rootfs_sha256";
    public static final String KEY_ROOTFS_URL = "payload_rootfs_url";

    private PayloadState() {
    }

    public static void storeRootfs(Context context, String sha256, String url) {
        ManifestService.prefs(context).edit()
                .putString(KEY_ROOTFS_SHA, sha256 == null ? "" : sha256)
                .putString(KEY_ROOTFS_URL, url == null ? "" : url)
                .apply();
    }

    /** @return the manifest sha256 the installed rootfs was built from, or null when unknown. */
    public static String rootfsSha256(Context context) {
        String sha = ManifestService.prefs(context).getString(KEY_ROOTFS_SHA, "");
        return (sha == null || sha.isEmpty()) ? null : sha;
    }

    /** @return true when the installed rootfs was fetched from this exact manifest asset. */
    public static boolean rootfsMatches(Context context, RemoteManifest.Asset asset) {
        String want = asset == null ? null : asset.sha256;
        if (want == null || want.isEmpty()) return true; // manifest carries no checksum — trust local
        String have = rootfsSha256(context);
        return have != null && have.equalsIgnoreCase(want);
    }
}
