package com.opxdemon.engine;

import android.content.Context;
import android.os.Build;

import com.opxdemon.utils.Core;

public enum EngineType {
    CHROOT,
    ROOTLESS,
    TOUR;

    public static final String PREF_KEY = "engine_type";

    public static EngineType active(Core core) {
        if (core == null) return CHROOT;
        String v = core.getString(PREF_KEY);
        if (v != null && v.equals(ROOTLESS.name())) return ROOTLESS;
        if (v != null && v.equals(TOUR.name())) return TOUR;
        return CHROOT;
    }

    public static boolean isRootless(Core core) {
        return active(core) == ROOTLESS;
    }

    public static boolean isTour(Core core) {
        if (core == null) return false;
        String v = core.getString(PREF_KEY);
        return v != null && v.equals(TOUR.name());
    }

    public static boolean isChosen(Core core) {
        if (core == null) return false;
        String v = core.getString(PREF_KEY);
        return v != null && !v.isEmpty();
    }

    public static void persist(Core core, EngineType type) {
        core.putString(PREF_KEY, type.name());
        try {
            java.io.File flag = RootlessPaths.activeFlag(core.context);
            if (type == ROOTLESS) {
                java.io.File dir = flag.getParentFile();
                if (dir != null && !dir.exists()) //noinspection ResultOfMethodCallIgnored
                    dir.mkdirs();
                try (java.io.FileWriter w = new java.io.FileWriter(flag, false)) { w.write("1"); }
            } else if (flag.exists()) {
                //noinspection ResultOfMethodCallIgnored
                flag.delete();
            }
        } catch (Exception ignored) {}
    }

    public static boolean rootlessSupported(Context context) {
        if (Build.SUPPORTED_ABIS == null) return false;
        for (String abi : Build.SUPPORTED_ABIS) {
            if ("arm64-v8a".equals(abi)) return true;
        }
        return false;
    }
}
