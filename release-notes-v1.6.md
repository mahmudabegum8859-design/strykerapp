**OPXdemon 1.6** — reliable boot + USB attach hardening, by **OP AMINUL FF** / **OPX**.

### The bug you kept hitting

Your log showed `VM boot failed (stopped)` over and over — then, after many
retries, a boot that *sometimes* worked. Two separate bugs caused it:

1. **Every retry killed itself before it started.** The engine's boot path began
   by cleaning up the *previous* QEMU process — but that cleanup used the same
   code path as the user-visible Stop button, which sets a "stop requested" flag.
   The new boot attempt then read that flag and returned `stopped` instantly.
   Pressing Start while a previous attempt was still winding down therefore
   always produced an instant failure, which is the loop you saw in the log.
2. **The 150 s boot timeout was too short.** On a slow phone the first boot
   (TCG emulation + disk grow + filesystem resize) takes ~170 s, so a healthy
   boot was being killed by the timer. The app then fell back to the "safe
   profile" and re-booted from scratch — making it even slower.

### What's new in 1.6

- **Boot attempts no longer kill themselves.** Pre-boot cleanup now tears down
  the old VM without setting the stop flag, so each Start is a clean, real boot
  attempt. No more instant `stopped`.
- **Progress-based boot timeout.** The engine waits 3 minutes, then extends the
  deadline 60 s at a time while the guest keeps producing boot output, up to a
  6-minute cap. A slow-but-healthy boot succeeds; a hung VM still fails fast
  (60 s after it stops producing output).
- **USB stays attached on the safe profile.** The fallback profile now keeps the
  USB host controller and the log message matches reality (the old message
  claimed "no USB HC" even though passthrough was on).
- **USB attach retries and real error messages.** The attach flow now retries
  `openDevice` (which can briefly fail right after the permission dialog),
  checks the USB file descriptor explicitly, reconnects the QMP control channel
  if it was down, and reports the *actual* failure reason in the dialog instead
  of the generic "Couldn't attach — grant USB access, then retry".
- **Guest Wi-Fi firmware install fixed.** The guest now points DNS at the VM's
  built-in resolver and refreshes the apt index (with retries) before installing
  `firmware-ath9k-htc` — previously it failed with "no network in the VM?".

> Verified against the actual Android 8+ USB stack: `UsbDeviceConnection
> getFileDescriptor()` returns the real usbfs descriptor on AOSP (the "always
> -1" claim is a myth — the native code returns the fd of an open connection),
> so fd-based passthrough works on Android 10 without root.

- versionCode **7**, versionName **1.6**.

### Assets

- `OPXdemon-1.6.apk` — the app (debug-signed, sideloadable)

> For authorized security testing only. You are responsible for complying with all applicable laws.
