package com.opxdemon;

import android.os.Build;

import com.opxdemon.engine.EngineType;
import com.opxdemon.logger.LogEntry;
import com.opxdemon.logger.LogStore;
import com.opxdemon.ota.NotificationCenter;
import com.opxdemon.ota.UpdateScheduler;
import com.opxdemon.utils.Core;

public class OPXDemonApp extends com.opxdemon.terminal.App {

    @Override
    public void onCreate() {
        super.onCreate();
        LogStore store = LogStore.init(this);
        store.add(LogEntry.INFO, "session", "==== OPXDemon " + BuildConfig.VERSION_NAME
                + " session start ====");
        String abi = Build.SUPPORTED_ABIS.length > 0 ? Build.SUPPORTED_ABIS[0] : "unknown";
        store.add(LogEntry.INFO, "session", "Device: " + Build.MANUFACTURER + " " + Build.MODEL
                + " · Android " + Build.VERSION.RELEASE
                + " (" + abi + ")");
        NotificationCenter.ensureChannel(this);
        // Tour mode is view-only: no background update/news polling.
        if (!EngineType.isTour(new Core(this))) {
            UpdateScheduler.schedule(this);
        }
    }
}
