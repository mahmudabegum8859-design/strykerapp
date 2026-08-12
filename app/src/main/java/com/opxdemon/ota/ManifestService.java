package com.opxdemon.ota;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONException;

public final class ManifestService {

    private static final int MAX_MANIFEST_BYTES = 512 * 1024;
    private static final String KEY_CACHE = "manifest_cache";

    private ManifestService() {
    }

    public static RemoteManifest fetch(Context context) {
        SharedPreferences prefs = prefs(context);
        try {
            String json = Net.getString(OPXDemonEndpoints.MANIFEST_URL, MAX_MANIFEST_BYTES);
            RemoteManifest manifest = RemoteManifest.fromJson(json);
            prefs.edit().putString(KEY_CACHE, json).apply();
            return manifest;
        } catch (Exception e) {
            return cached(context);
        }
    }

    public static RemoteManifest cached(Context context) {
        String json = prefs(context).getString(KEY_CACHE, null);
        if (json == null || json.isEmpty()) {
            return null;
        }
        try {
            return RemoteManifest.fromJson(json);
        } catch (JSONException e) {
            return null;
        }
    }

    /**
     * Drops the cached manifest so the next fetch() gets a fresh copy.
     * Used when a payload download fails its size/checksum verification: that
     * usually means the release changed after we cached the manifest, so the
     * cached copy is stale and must not keep being served.
     */
    public static void invalidate(Context context) {
        prefs(context).edit().remove(KEY_CACHE).apply();
    }

    static SharedPreferences prefs(Context context) {
        return context.getApplicationContext()
                .getSharedPreferences(OPXDemonEndpoints.PREFS, Context.MODE_PRIVATE);
    }
}
