package com.opxdemon.engine;

import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbConstants;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbInterface;
import android.hardware.usb.UsbManager;
import android.os.Build;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

public final class UsbPassthroughManager {

    private static final String TAG = "UsbPassthrough";
    private static final String ACTION_USB_PERMISSION = "com.opxdemon.USB_PERMISSION";

    private final Context context;
    private final UsbManager usbManager;
    private final QmpClient qmp;

    private final Map<Integer, Attached> attached = new HashMap<>();
    private final Map<Integer, PermissionCallback> permissionCallbacks = new HashMap<>();
    private volatile boolean receiverRegistered = false;
    private volatile CountDownLatch pendingPermission;
    private volatile int awaitingDeviceId = -1;
    private volatile String lastAttachError = "";

    /** Why the last attach failed, for the UI to show a real reason. */
    public String lastAttachError() {
        return lastAttachError == null ? "" : lastAttachError;
    }

    public interface PermissionCallback { void onResult(boolean granted, UsbDevice device); }

    public interface AttachCallback { void onResult(boolean attached, UsbDevice device); }

    private static final class Attached {
        final UsbDeviceConnection connection;
        final ParcelFileDescriptor pfd;
        final int fdSetId;
        final String qemuId;
        Attached(UsbDeviceConnection c, ParcelFileDescriptor p, int fdSetId, String qemuId) {
            this.connection = c; this.pfd = p; this.fdSetId = fdSetId; this.qemuId = qemuId;
        }
    }

    public UsbPassthroughManager(Context context, QmpClient qmp) {
        this.context = context.getApplicationContext();
        this.usbManager = (UsbManager) this.context.getSystemService(Context.USB_SERVICE);
        this.qmp = qmp;
    }

    public UsbDevice findByVidPid(String vidPid) {
        if (usbManager == null || vidPid == null) return null;
        String[] p = vidPid.split(":");
        if (p.length != 2) return null;
        int vid, pid;
        try {
            vid = Integer.parseInt(p[0].trim(), 16);
            pid = Integer.parseInt(p[1].trim(), 16);
        } catch (NumberFormatException e) {
            return null;
        }
        for (UsbDevice d : usbManager.getDeviceList().values()) {
            if (d.getVendorId() == vid && d.getProductId() == pid) return d;
        }
        return null;
    }

    public boolean hasPermission(UsbDevice device) {
        return usbManager != null && device != null && usbManager.hasPermission(device);
    }

    public boolean isAttached(UsbDevice device) {
        return device != null && attached.containsKey(device.getDeviceId());
    }

    public void requestUsbPermission(UsbDevice device, PermissionCallback cb) {
        if (usbManager == null || device == null) { if (cb != null) cb.onResult(false, device); return; }
        synchronized (permissionCallbacks) { permissionCallbacks.put(device.getDeviceId(), cb); }
        registerReceiver();
        usbManager.requestPermission(device, permissionIntent(device));
    }

    private PendingIntent permissionIntent(UsbDevice device) {
        int flags = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ? PendingIntent.FLAG_MUTABLE : 0;
        return PendingIntent.getBroadcast(context, device.getDeviceId(),
                new Intent(ACTION_USB_PERMISSION).setPackage(context.getPackageName()), flags);
    }

    public void attachAsync(UsbDevice device, AttachCallback done) {
        if (device == null) { if (done != null) done.onResult(false, null); return; }
        if (isAttached(device)) { if (done != null) done.onResult(true, device); return; }
        if (hasPermission(device)) {
            boolean ok = attach(device);
            if (done != null) done.onResult(ok, device);
            return;
        }
        requestUsbPermission(device, (granted, d) -> {
            boolean ok = granted && attach(device);
            if (done != null) done.onResult(ok, device);
        });
    }

    public synchronized boolean attach(UsbDevice device) {
        if (device == null || qmp == null) {
            lastAttachError = qmp == null
                    ? "VM control channel is not ready — wait for the VM to finish booting, then retry"
                    : "no adapter selected";
            return false;
        }
        if (attached.containsKey(device.getDeviceId())) return true;
        UsbDeviceConnection connection = openDeviceWithRetry(device);
        if (connection == null) {
            lastAttachError = "Android refused to open the adapter — replug it and retry "
                    + "(another app may currently hold it)";
            Log.w(TAG, "openDevice returned null for " + device.getDeviceName());
            return false;
        }
        claimInterfaces(device, connection);
        // On AOSP this returns the real usbfs fd for an open connection. Some OEM
        // ROMs still block it; report that instead of a generic "grant USB access".
        int rawFd = connection.getFileDescriptor();
        if (rawFd < 0) {
            lastAttachError = "Android blocked the USB file descriptor on this ROM — "
                    + "replug the adapter and retry, or use the rooted mode";
            try { connection.close(); } catch (Throwable ignored) {}
            return false;
        }
        ParcelFileDescriptor pfd;
        try {
            pfd = ParcelFileDescriptor.fromFd(rawFd);
        } catch (java.io.IOException e) {
            lastAttachError = "Could not wrap the USB fd (" + e.getMessage() + ")";
            try { connection.close(); } catch (Throwable ignored) {}
            return false;
        }
        if (pfd == null) {
            lastAttachError = "Could not wrap the USB fd";
            try { connection.close(); } catch (Throwable ignored) {}
            return false;
        }
        int fdSetId = qmp.addFd(pfd.getFileDescriptor());
        if (fdSetId < 0) {
            lastAttachError = "VM rejected the USB fd — is the VM fully booted? "
                    + "Restart the VM, then retry";
            try { pfd.close(); } catch (Exception ignored) {}
            try { connection.close(); } catch (Throwable ignored) {}
            return false;
        }
        String qemuId = "opxdemon_usb_" + device.getDeviceId();
        try {
            JSONObject args = new JSONObject();
            args.put("driver", "usb-host");
            args.put("id", qemuId);
            args.put("bus", "usbhc0.0");
            args.put("hostdevice", "/dev/fdset/" + fdSetId);
            if (!qmp.deviceAdd(args)) {
                lastAttachError = "VM refused to add the USB adapter — check the boot log "
                        + "(driver/firmware for this chipset may be missing)";
                qmp.removeFd(fdSetId);
                try { pfd.close(); } catch (Exception ignored) {}
                try { connection.close(); } catch (Throwable ignored) {}
                return false;
            }
        } catch (JSONException e) {
            lastAttachError = "Could not build the USB attach command";
            qmp.removeFd(fdSetId);
            try { pfd.close(); } catch (Exception ignored) {}
            try { connection.close(); } catch (Throwable ignored) {}
            return false;
        }
        registerReceiver();
        attached.put(device.getDeviceId(), new Attached(connection, pfd, fdSetId, qemuId));
        lastAttachError = "";
        Log.i(TAG, "Attached USB device " + device.getDeviceName() + " as " + qemuId);
        return true;
    }

    /** openDevice can briefly fail right after the permission dialog — retry a few times. */
    private UsbDeviceConnection openDeviceWithRetry(UsbDevice device) {
        UsbDeviceConnection c = usbManager.openDevice(device);
        if (c != null) return c;
        for (int i = 0; i < 3; i++) {
            try { Thread.sleep(500); } catch (InterruptedException e) { break; }
            c = usbManager.openDevice(device);
            if (c != null) return c;
        }
        return null;
    }

    private void claimInterfaces(UsbDevice device, UsbDeviceConnection connection) {
        int count = device.getInterfaceCount();
        for (int i = 0; i < count; i++) {
            UsbInterface iface = device.getInterface(i);
            boolean ok;
            try {
                ok = connection.claimInterface(iface, true);
            } catch (Throwable t) {
                ok = false;
            }
            if (ok) continue;
            Log.w(TAG, "claimInterface " + iface.getId() + " failed on " + device.getDeviceName());
            GuestExec.logToStore("USB: could not claim interface " + iface.getId() + " of "
                    + device.getDeviceName() + " — an Android driver still holds it, the guest will "
                    + "only get endpoint 0");
        }
    }

    public synchronized void detach(int deviceId) {
        Attached a = attached.remove(deviceId);
        if (a == null) return;
        try { qmp.deviceDel(a.qemuId); } catch (Exception ignored) {}
        try { qmp.removeFd(a.fdSetId); } catch (Exception ignored) {}
        try { a.pfd.close(); } catch (Exception ignored) {}
        try { a.connection.close(); } catch (Exception ignored) {}
    }

    public synchronized void detachAll() {
        for (Integer id : new java.util.ArrayList<>(attached.keySet())) {
            detach(id);
        }
        unregisterReceiver();
    }

    public synchronized boolean hasAttached() {
        return !attached.isEmpty();
    }

    public synchronized int attachedCount() {
        return attached.size();
    }

    public boolean isWifiCandidate(UsbDevice d) {
        if (d == null || d.getDeviceClass() == UsbConstants.USB_CLASS_HUB) return false;
        for (int i = 0; i < d.getInterfaceCount(); i++) {
            UsbInterface intf = d.getInterface(i);
            if (intf.getInterfaceClass() == UsbConstants.USB_CLASS_VENDOR_SPEC
                    || intf.getInterfaceClass() == UsbConstants.USB_CLASS_WIRELESS_CONTROLLER) {
                return true;
            }
        }
        return false;
    }

    public java.util.List<UsbDevice> pickWifiDevices() {
        java.util.List<UsbDevice> out = new java.util.ArrayList<>();
        if (usbManager == null) return out;
        for (UsbDevice d : usbManager.getDeviceList().values()) {
            if (isWifiCandidate(d)) out.add(d);
        }
        java.util.Collections.sort(out, (a, b) -> Integer.compare(a.getDeviceId(), b.getDeviceId()));
        return out;
    }

    public int attachAllWifiDongles(long waitMs) {
        java.util.List<UsbDevice> picks = pickWifiDevices();
        if (picks.isEmpty()) return 0;
        int ok = 0;
        for (UsbDevice d : picks) {
            if (isAttached(d)) { ok++; continue; }
            if (!usbManager.hasPermission(d)
                    && (!requestPermissionBlocking(d, waitMs) || !usbManager.hasPermission(d))) {
                Log.w(TAG, "USB permission not granted for " + d.getDeviceName());
                continue;
            }
            if (attach(d)) ok++;
        }
        return ok;
    }

    public UsbDevice pickWifiDevice() {
        java.util.List<UsbDevice> picks = pickWifiDevices();
        return picks.isEmpty() ? null : picks.get(0);
    }

    private boolean requestPermissionBlocking(UsbDevice device, long waitMs) {
        pendingPermission = new CountDownLatch(1);
        awaitingDeviceId = device.getDeviceId();
        registerReceiver();
        usbManager.requestPermission(device, permissionIntent(device));
        try {
            return pendingPermission.await(waitMs, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            return false;
        } finally {
            awaitingDeviceId = -1;
        }
    }

    private final BroadcastReceiver receiver = new BroadcastReceiver() {
        @Override public void onReceive(Context c, Intent intent) {
            if (ACTION_USB_PERMISSION.equals(intent.getAction())) {
                boolean granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false);
                UsbDevice d = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                if (pendingPermission != null
                        && (d == null || d.getDeviceId() == awaitingDeviceId)) {
                    pendingPermission.countDown();
                }
                PermissionCallback cb = null;
                synchronized (permissionCallbacks) {
                    if (d != null) {
                        cb = permissionCallbacks.remove(d.getDeviceId());
                    } else if (permissionCallbacks.size() == 1) {
                        Integer only = permissionCallbacks.keySet().iterator().next();
                        cb = permissionCallbacks.remove(only);
                    }
                }
                if (cb != null) cb.onResult(granted, d);
            } else if (UsbManager.ACTION_USB_DEVICE_DETACHED.equals(intent.getAction())) {
                UsbDevice d = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                if (d != null) detach(d.getDeviceId());
            }
        }
    };

    private android.os.HandlerThread receiverThread;
    private android.os.Handler receiverHandler;

    private void registerReceiver() {
        if (receiverRegistered) return;
        if (receiverThread == null) {
            receiverThread = new android.os.HandlerThread("usb-permission");
            receiverThread.start();
            receiverHandler = new android.os.Handler(receiverThread.getLooper());
        }
        IntentFilter filter = new IntentFilter();
        filter.addAction(ACTION_USB_PERMISSION);
        filter.addAction(UsbManager.ACTION_USB_DEVICE_DETACHED);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, null, receiverHandler,
                    Context.RECEIVER_NOT_EXPORTED);
        } else {
            context.registerReceiver(receiver, filter, null, receiverHandler);
        }
        receiverRegistered = true;
    }

    private void unregisterReceiver() {
        if (!receiverRegistered) return;
        try { context.unregisterReceiver(receiver); } catch (Exception ignored) {}
        receiverRegistered = false;
        if (receiverThread != null) {
            receiverThread.quitSafely();
            receiverThread = null;
            receiverHandler = null;
        }
        synchronized (permissionCallbacks) { permissionCallbacks.clear(); }
    }
}
