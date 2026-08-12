**OPXdemon 1.6.1** — boot timeout fix + stop-flag hardening, by **OP AMINUL FF** / **OPX**.

### Why 1.6 still failed to boot on your phone

Your 1.6 log showed two things:

1. **`Boot timed out after 62s` — this was a bug I introduced in 1.6.** The new
   progress-based timeout read the wrong progress file (QEMU stdout, which stays
   empty because the guest console goes to the serial log) and its baseline was
   initialized to "unknown", so the very first check capped the wait at 60 s
   instead of the intended 180 s. Every boot attempt — normal and safe profile —
   was killed at ~1 minute, far sooner than the ~3-4 minutes a first boot on a
   phone actually needs under TCG emulation.
2. **`VM boot failed (stopped)` kept appearing.** The stop flag is sticky, and
   several teardown paths (Stop button, service destruction, feature calls
   restarting the VM mid-boot) set it in a way that killed the next boot attempt
   instantly.

### What's new in 1.6.1

- **Boot progress is now measured on the real guest console** (serial log +
  stdout, whichever grows) with a correct baseline — the 180 s base window and
  60 s-per-progress extensions up to 7 minutes now work as designed.
- **Stop detection is generation-based.** A boot attempt only treats a stop that
  happens *after it started* as "stopped". Tearing down an old VM (previous
  session's service, old QEMU) can no longer kill a fresh boot.
- **"stopped" no longer triggers the safe-profile fallback** — it is not a boot
  failure, so nothing is retried; the VM simply stays stopped.
- **No more orphan QEMU after a timeout** — a timed-out boot kills its own QEMU,
  so the next attempt (or a status poll) does not see a live-but-unbooted VM.
- **Feature calls no longer restart a booting VM.** `exec()`/`openStream()`
  (terminal, wifi scans, monitor actions) used to auto-start the VM when it was
  not ready — during a long first boot every tap killed the booting VM and
  restarted it from zero, which is why boots "never finished". Now they just say
  "VM is still booting — wait for it to finish".
- **Faster VM teardown** — kills escalate (2 s grace → destroy → force) instead
  of waiting 12 s on a healthy VM.

> **What to do:** install the 1.6.1 APK, press Start **once**, and wait 3-5
> minutes for the first boot. Don't press Stop or retry while it boots — it will
> now tell you when it is ready instead of failing at 60 s.

- versionCode **8**, versionName **1.6.1**.

### Assets

- `OPXdemon-1.6.1.apk` — the app (debug-signed, sideloadable)

> For authorized security testing only. You are responsible for complying with all applicable laws.
