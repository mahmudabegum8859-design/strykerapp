package com.opxdemon.engine;

import android.content.Context;
import android.content.res.AssetManager;
import android.util.Log;

import com.opxdemon.ota.PayloadState;
import com.opxdemon.ota.QemuDownloader;
import com.opxdemon.ota.RemoteManifest;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.zip.GZIPInputStream;

public final class QemuInstaller {

    private static final String TAG = "QemuInstaller";
    private static final String ASSET_DIR = "rootless";

    public interface Progress {
        void onStage(Stage stage);
        void onBytes(String label, long done);
        void onLog(int level, String message);
    }

    public enum Stage {
        PREPARING("Preparing"),
        EXTRACTING_QEMU("Extracting QEMU"),
        EXTRACTING_KERNEL("Extracting kernel"),
        EXTRACTING_LIBS("Extracting libraries"),
        DECOMPRESSING_ROOTFS("Decompressing rootfs"),
        FINALIZING("Finalizing"),
        DONE("Done");

        public final String title;
        Stage(String title) { this.title = title; }
    }

    private QemuInstaller() {}

    private static String rootfsAssetName(Context c) {
        try {
            String[] files = c.getAssets().list(ASSET_DIR);
            if (files == null) return null;
            String imgz = null, gz = null, raw = null;
            for (String f : files) {
                if (f.equals("rootfs-" + RootlessPaths.arch(c).key + ".imgz")) imgz = f;
                else if (f.equals("rootfs.imgz")) imgz = f;
                else if (f.equals("rootfs.img.gz")) gz = f;
                else if (f.equals("rootfs.img")) raw = f;
            }
            if (imgz != null) return imgz;
            if (gz != null) return gz;
            return raw;
        } catch (IOException e) {
            return null;
        }
    }

    private static boolean isCompressed(String assetName) {
        return assetName != null && (assetName.endsWith(".imgz") || assetName.endsWith(".gz"));
    }

    public static boolean assetsPresent(Context c) {
        GuestArch arch = RootlessPaths.arch(c);
        try {
            String[] files = c.getAssets().list(ASSET_DIR);
            if (files == null) return false;
            boolean q = false, k = false, l = true, ird = false;
            for (String f : files) {
                if (f.equals(arch.qemuName)) q = true;
                else if (f.equals(arch.kernelName)) k = true;
                else if (f.equals("libslirp.so")) l = true;
                else if (f.equals(arch.initrdName)) ird = true;
            }
            if (arch.needsLibslirp && !l) return false;
            return q && k && ird && rootfsAssetName(c) != null;
        } catch (IOException e) {
            return false;
        }
    }

    public static boolean install(Context context, Progress p) {
        if (!assetsPresent(context)) {
            log(p, 1, "No bundled artifacts — fetching the engine from the release");
            return installFromNetwork(context, p);
        }
        return installFromAssets(context, p);
    }

    private static boolean installFromAssets(Context context, Progress p) {
        AssetManager am = context.getAssets();
        File base = RootlessPaths.base(context);
        try {
            stage(p, Stage.PREPARING);
            if (!base.exists() && !base.mkdirs()) {
                log(p, 3, "Cannot create " + base.getAbsolutePath());
                return false;
            }

            GuestArch arch = RootlessPaths.arch(context);
            stage(p, Stage.EXTRACTING_QEMU);
            copyAsset(am, ASSET_DIR + "/" + arch.qemuName, RootlessPaths.qemuBin(context), p, "QEMU");
            RootlessPaths.qemuBin(context).setExecutable(true, false);

            stage(p, Stage.EXTRACTING_KERNEL);
            copyAsset(am, ASSET_DIR + "/" + arch.kernelName, RootlessPaths.kernel(context), p, "kernel");
            copyAsset(am, ASSET_DIR + "/" + arch.initrdName, RootlessPaths.initrd(context), p, "initrd");

            stage(p, Stage.EXTRACTING_LIBS);
            if (arch.needsLibslirp) {
                copyAsset(am, ASSET_DIR + "/libslirp.so", RootlessPaths.libslirp(context), p, "libslirp.so");
            }

            stage(p, Stage.DECOMPRESSING_ROOTFS);
            String rootfsAsset = rootfsAssetName(context);
            if (rootfsAsset == null) {
                log(p, 3, "rootfs asset not found in assets/rootless");
                return false;
            }
            if (isCompressed(rootfsAsset)) {
                log(p, 1, "Decompressing " + rootfsAsset + " (this can take a minute)");
                gunzipAsset(am, ASSET_DIR + "/" + rootfsAsset, RootlessPaths.rootfs(context), p);
            } else {
                log(p, 1, "Copying " + rootfsAsset + " (already decompressed by the build)");
                copyAsset(am, ASSET_DIR + "/" + rootfsAsset, RootlessPaths.rootfs(context), p, "rootfs.img");
            }

            stage(p, Stage.FINALIZING);
            ensureMinimumDisk(context, p);
            boolean ok = RootlessEngine.get(context).isInstalled();
            if (ok) {
                stage(p, Stage.DONE);
                log(p, 2, "Rootless engine installed");
            } else {
                log(p, 3, "Post-install verification failed");
            }
            return ok;
        } catch (Exception e) {
            Log.e(TAG, "install failed", e);
            log(p, 3, "Install error: " + e.getMessage());
            return false;
        }
    }

    private static boolean installFromNetwork(Context context, Progress p) {
        File base = RootlessPaths.base(context);
        try {
            stage(p, Stage.PREPARING);
            if (!base.exists() && !base.mkdirs()) {
                log(p, 3, "Cannot create " + base.getAbsolutePath());
                return false;
            }
            QemuDownloader.Bundle b = QemuDownloader.resolve(context);

            stage(p, Stage.EXTRACTING_QEMU);
            if (fetch(context, b.qemu, RootlessPaths.qemuBin(context), "QEMU", p) == null) return false;
            RootlessPaths.qemuBin(context).setExecutable(true, false);

            stage(p, Stage.EXTRACTING_KERNEL);
            if (fetch(context, b.kernel, RootlessPaths.kernel(context), "kernel", p) == null) return false;
            if (fetch(context, b.initrd, RootlessPaths.initrd(context), "initrd", p) == null) return false;

            stage(p, Stage.EXTRACTING_LIBS);
            if (RootlessPaths.arch(context).needsLibslirp
                    && b.libslirp != null && b.libslirp.isUsable()) {
                if (fetch(context, b.libslirp, RootlessPaths.libslirp(context),
                        "libslirp.so", p) == null) return false;
            }

            stage(p, Stage.DECOMPRESSING_ROOTFS);
            File rootfs = RootlessPaths.rootfs(context);
            RemoteManifest.Asset rootfsAsset = b.rootfs;
            boolean compressed = rootfsAsset != null && rootfsAsset.url != null
                    && (rootfsAsset.url.endsWith(".imgz") || rootfsAsset.url.endsWith(".gz"));
            if (!compressed) {
                rootfsAsset = fetch(context, rootfsAsset, rootfs, "rootfs.img", p);
                if (rootfsAsset == null) return false;
            } else {
                File archive = new File(base, "rootfs.download");
                rootfsAsset = fetch(context, rootfsAsset, archive, "rootfs", p);
                if (rootfsAsset == null) return false;
                log(p, 1, "Decompressing rootfs (this can take a minute)");
                if (!gunzipFile(archive, rootfs, p)) {
                    //noinspection ResultOfMethodCallIgnored
                    archive.delete();
                    return false;
                }
                //noinspection ResultOfMethodCallIgnored
                archive.delete();
            }

            stage(p, Stage.FINALIZING);
            ensureMinimumDisk(context, p);
            boolean ok = RootlessEngine.get(context).isInstalled();
            if (ok) {
                // Remember which release this rootfs came from so the engine can
                // detect newer payloads (e.g. the USB Wi-Fi firmware release) on
                // later boots and refresh them automatically. Use the asset that
                // was actually installed, which may be a freshly resolved copy
                // after a stale-manifest retry.
                PayloadState.storeRootfs(context,
                        rootfsAsset == null ? null : rootfsAsset.sha256,
                        rootfsAsset == null ? null : rootfsAsset.url);
                stage(p, Stage.DONE);
                log(p, 2, "Rootless engine installed");
            } else {
                log(p, 3, "Post-install verification failed");
            }
            return ok;
        } catch (Exception e) {
            Log.e(TAG, "network install failed", e);
            log(p, 3, "Install error: " + e.getMessage());
            return false;
        }
    }

    /**
     * True when any of the installed engine payloads no longer matches the
     * current release (manifest sha256 differs, or a file is missing).
     * The small files are hashed on disk; the decompressed rootfs is compared
     * through the fingerprint stored at install time.
     */
    public static boolean needsUpdate(Context context) {
        if (RootlessEngine.get(context).isRunning()) return false;
        // Nothing installed at all — a fresh install is required, not an update.
        // Once the QEMU binary exists we treat missing/stale files (including a
        // pre-libslirp install that predates the bionic engine) as repairable.
        if (!RootlessPaths.qemuBin(context).exists()) return false;
        QemuDownloader.Bundle b = QemuDownloader.resolve(context);
        if (b == null || !b.isUsable()) return false;
        if (!PayloadState.rootfsMatches(context, b.rootfs)) return true;
        if (!fileMatches(RootlessPaths.qemuBin(context), b.qemu)) return true;
        if (!fileMatches(RootlessPaths.kernel(context), b.kernel)) return true;
        if (!fileMatches(RootlessPaths.initrd(context), b.initrd)) return true;
        if (RootlessPaths.arch(context).needsLibslirp && b.libslirp != null && b.libslirp.isUsable()
                && !fileMatches(RootlessPaths.libslirp(context), b.libslirp)) return true;
        return false;
    }

    /**
     * Re-downloads only the engine payloads whose checksum changed on the
     * release, then records the new rootfs fingerprint. The running engine is
     * never touched; files are replaced atomically (verified download + rename).
     *
     * @return true when the engine is current afterwards (or already was).
     */
    public static boolean updateIfNeeded(Context context, Progress p) {
        QemuDownloader.Bundle b = QemuDownloader.resolve(context);
        if (b == null || !b.isUsable()) {
            log(p, 3, "Payload update: no usable payload set in the manifest");
            return false;
        }
        if (RootlessEngine.get(context).isRunning()) {
            log(p, 2, "Payload update skipped — VM is running");
            return true;
        }
        boolean any = false;

        if (!fileMatches(RootlessPaths.qemuBin(context), b.qemu)) {
            if (fetch(context, b.qemu, RootlessPaths.qemuBin(context), "QEMU", p) == null) return false;
            RootlessPaths.qemuBin(context).setExecutable(true, false);
            any = true;
        }
        if (!fileMatches(RootlessPaths.kernel(context), b.kernel)) {
            if (fetch(context, b.kernel, RootlessPaths.kernel(context), "kernel", p) == null) return false;
            any = true;
        }
        if (!fileMatches(RootlessPaths.initrd(context), b.initrd)) {
            if (fetch(context, b.initrd, RootlessPaths.initrd(context), "initrd", p) == null) return false;
            any = true;
        }
        if (RootlessPaths.arch(context).needsLibslirp && b.libslirp != null && b.libslirp.isUsable()
                && !fileMatches(RootlessPaths.libslirp(context), b.libslirp)) {
            if (fetch(context, b.libslirp, RootlessPaths.libslirp(context),
                    "libslirp.so", p) == null) return false;
            any = true;
        }

        // The rootfs is the big one and the one that carries driver/firmware
        // updates — refresh it last, keeping the old image until the new one is
        // fully downloaded and decompressed.
        if (!PayloadState.rootfsMatches(context, b.rootfs)) {
            File rootfs = RootlessPaths.rootfs(context);
            File archive = new File(RootlessPaths.base(context), "rootfs.download");
            RemoteManifest.Asset rootfsAsset = fetch(context, b.rootfs, archive, "rootfs", p);
            if (rootfsAsset == null) return false;
            log(p, 1, "Decompressing updated rootfs (this can take a minute)");
            if (!gunzipFile(archive, rootfs, p)) {
                //noinspection ResultOfMethodCallIgnored
                archive.delete();
                return false;
            }
            //noinspection ResultOfMethodCallIgnored
            archive.delete();
            PayloadState.storeRootfs(context, rootfsAsset.sha256, rootfsAsset.url);
            any = true;
        }

        log(p, any ? 2 : 2, any
                ? "Engine payloads updated to the latest release"
                : "Engine payloads are already current");
        return true;
    }

    /** True when the local file has the exact sha256 the manifest expects. */
    private static boolean fileMatches(File file, RemoteManifest.Asset asset) {
        if (asset == null || asset.sha256 == null || asset.sha256.isEmpty()) return true;
        if (file == null || !file.exists()) return false;
        return asset.sha256.equalsIgnoreCase(sha256Of(file));
    }

    private static String sha256Of(File file) {
        try (java.io.InputStream in = new java.io.FileInputStream(file)) {
            java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
            byte[] buf = new byte[1 << 16];
            int r;
            while ((r = in.read(buf)) != -1) md.update(buf, 0, r);
            StringBuilder sb = new StringBuilder(64);
            for (byte b : md.digest()) sb.append(Character.forDigit((b >> 4) & 0xF, 16))
                    .append(Character.forDigit(b & 0xF, 16));
            return sb.toString();
        } catch (Exception e) {
            return "";
        }
    }

    /**
     * Downloads one payload with sha256/size verification.
     *
     * @return the asset that was actually installed — the requested one, or a
     *         freshly resolved copy when a size/checksum mismatch proved the
     *         cached manifest was stale — or {@code null} on failure.
     */
    private static com.opxdemon.ota.RemoteManifest.Asset fetch(Context context,
            com.opxdemon.ota.RemoteManifest.Asset asset, File dest, String label, Progress p) {
        if (asset == null || !asset.isUsable()) {
            log(p, 3, label + ": no download URL in the manifest");
            return null;
        }
        com.opxdemon.ota.RemoteManifest.Asset used = asset;
        com.opxdemon.ota.VerifiedDownloader.Result r = doFetch(used, dest, label, p);

        // A size/checksum mismatch usually means the release payload changed
        // after we cached the manifest. Drop the stale cache, fetch the
        // manifest again and retry once with the fresh values instead of
        // failing the whole install.
        if (!r.ok && r.error != null
                && (r.error.startsWith("Size mismatch") || r.error.startsWith("Checksum"))) {
            log(p, 1, label + ": " + r.error
                    + " — the release changed; refreshing the manifest and retrying once");
            com.opxdemon.ota.ManifestService.invalidate(context);
            com.opxdemon.ota.RemoteManifest.Asset fresh = resolveFresh(context, label);
            if (fresh != null && fresh.isUsable() && !sameAsset(used, fresh)) {
                used = fresh;
                r = doFetch(used, dest, label, p);
            }
        }

        if (!r.ok) {
            log(p, 3, label + ": " + r.error);
            return null;
        }
        if (used.sha256 == null || used.sha256.isEmpty()) {
            log(p, 1, label + " downloaded but the manifest carries no checksum");
        }
        log(p, 2, label + " ready (" + mb(dest.length()) + ")");
        return used;
    }

    private static com.opxdemon.ota.VerifiedDownloader.Result doFetch(
            com.opxdemon.ota.RemoteManifest.Asset asset, File dest, String label, Progress p) {
        log(p, 1, "GET " + asset.url);
        return com.opxdemon.ota.VerifiedDownloader.download(
                asset.url, dest, asset.sha256, asset.size,
                (done, total) -> { if (p != null) p.onBytes(label, done); });
    }

    /** Re-resolves one payload from a freshly fetched manifest. */
    private static com.opxdemon.ota.RemoteManifest.Asset resolveFresh(Context context, String label) {
        QemuDownloader.Bundle b = QemuDownloader.resolve(context);
        if (b == null) return null;
        if ("QEMU".equals(label)) return b.qemu;
        if ("kernel".equals(label)) return b.kernel;
        if ("initrd".equals(label)) return b.initrd;
        if ("libslirp.so".equals(label)) return b.libslirp;
        if ("rootfs".equals(label)) return b.rootfs;
        return null;
    }

    private static boolean sameAsset(com.opxdemon.ota.RemoteManifest.Asset a,
                                    com.opxdemon.ota.RemoteManifest.Asset b) {
        return a == b || (a != null && b != null
                && java.util.Objects.equals(a.url, b.url)
                && java.util.Objects.equals(a.sha256, b.sha256)
                && a.size == b.size);
    }

    private static boolean gunzipFile(File src, File dest, Progress p) {
        File tmp = new File(dest.getAbsolutePath() + ".tmp");
        long total = 0;
        try (GZIPInputStream in = new GZIPInputStream(new java.io.FileInputStream(src), 1 << 16);
             OutputStream out = new FileOutputStream(tmp)) {
            byte[] buf = new byte[1 << 16];
            int read;
            long lastReport = 0;
            while ((read = in.read(buf)) != -1) {
                out.write(buf, 0, read);
                total += read;
                if (total - lastReport > 16 * 1024 * 1024) {
                    lastReport = total;
                    if (p != null) p.onBytes("rootfs.img", total);
                }
            }
            out.flush();
        } catch (IOException e) {
            log(p, 3, "Decompression failed: " + e.getMessage());
            //noinspection ResultOfMethodCallIgnored
            tmp.delete();
            return false;
        }
        if (!tmp.renameTo(dest)) {
            //noinspection ResultOfMethodCallIgnored
            dest.delete();
            if (!tmp.renameTo(dest)) {
                log(p, 3, "rename failed for " + dest);
                return false;
            }
        }
        log(p, 2, "rootfs.img ready (" + mb(total) + ")");
        return true;
    }

    private static void ensureMinimumDisk(Context context, Progress p) {
        try {
            File img = RootlessPaths.rootfs(context);
            if (!img.exists()) return;
            long target = Math.min((long) VmSpecs.MIN_DISK_GB * VmSpecs.GB,
                    VmSpecs.autoDiskTargetBytes(context));
            if (img.length() >= target) return;
            try (java.io.RandomAccessFile raf = new java.io.RandomAccessFile(img, "rw")) {
                raf.setLength(target);
                raf.getFD().sync();
            }
            if (img.length() < target) {
                log(p, 3, "Could not reserve " + (target / VmSpecs.GB) + " GB for the VM disk");
                return;
            }
            com.opxdemon.utils.Core core = new com.opxdemon.utils.Core(context);
            core.putBoolean(VmSpecs.K_RESIZE_PENDING, true);
            log(p, 2, "VM disk starts at " + (target / VmSpecs.GB)
                    + " GB and grows into free storage automatically");
        } catch (Exception e) {
            log(p, 3, "Disk sizing skipped: " + e.getMessage());
        }
    }

    private static void copyAsset(AssetManager am, String assetPath, File dest, Progress p, String label)
            throws IOException {
        File tmp = new File(dest.getAbsolutePath() + ".tmp");
        long total = 0;
        try (InputStream in = am.open(assetPath);
             OutputStream out = new FileOutputStream(tmp)) {
            byte[] buf = new byte[1 << 16];
            int r;
            long lastReport = 0;
            while ((r = in.read(buf)) != -1) {
                out.write(buf, 0, r);
                total += r;
                if (total - lastReport > 4 * 1024 * 1024) {
                    lastReport = total;
                    if (p != null) p.onBytes(label, total);
                }
            }
            out.flush();
        }
        if (!tmp.renameTo(dest)) {
            //noinspection ResultOfMethodCallIgnored
            dest.delete();
            if (!tmp.renameTo(dest)) throw new IOException("rename failed for " + dest);
        }
        if (p != null) p.onBytes(label, total);
        log(p, 2, label + " extracted (" + mb(total) + ")");
    }

    private static void gunzipAsset(AssetManager am, String assetPath, File dest, Progress p)
            throws IOException {
        File tmp = new File(dest.getAbsolutePath() + ".tmp");
        long total = 0;
        try (GZIPInputStream in = new GZIPInputStream(am.open(assetPath), 1 << 16);
             OutputStream out = new FileOutputStream(tmp)) {
            byte[] buf = new byte[1 << 16];
            int r;
            long lastReport = 0;
            while ((r = in.read(buf)) != -1) {
                out.write(buf, 0, r);
                total += r;
                if (total - lastReport > 16 * 1024 * 1024) {
                    lastReport = total;
                    if (p != null) p.onBytes("rootfs.img", total);
                }
            }
            out.flush();
        }
        if (!tmp.renameTo(dest)) {
            //noinspection ResultOfMethodCallIgnored
            dest.delete();
            if (!tmp.renameTo(dest)) throw new IOException("rename failed for " + dest);
        }
        log(p, 2, "rootfs.img ready (" + mb(total) + ")");
    }

    private static String mb(long bytes) {
        return String.format(java.util.Locale.US, "%.1f MB", bytes / 1024.0 / 1024.0);
    }

    private static void stage(Progress p, Stage s) { if (p != null) p.onStage(s); }
    private static void log(Progress p, int level, String msg) { if (p != null) p.onLog(level, msg); }
}
