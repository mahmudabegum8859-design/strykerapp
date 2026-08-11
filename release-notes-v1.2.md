**OPXdemon 1.2** — bug-fix release by **OP AMINUL FF** / **OPX**.

### What's new in 1.2
- **Build fix**: the committed Gradle JVM settings exceeded the 2 GiB memory cap of
  sandboxed/preview containers, which OOM-killed plain `./gradlew assembleDebug` builds.
  Defaults are now memory-safe (`-Xmx768m`, tight Kotlin daemon) — the preview and CI
  builds work out of the box.
- **Preview page fix**: the served download page still claimed "v6.0 / versionCode 600"
  from the upstream project; it now shows the real version (1.2 / versionCode 2).
- **OTA fix**: the update manifest now carries the real APK `sha256` and `size`, so the
  in-app update prompt and checksum verification work (an empty checksum silently disabled
  the update prompt for 1.1 users).
- **Docs cleanup**: third-party notices now reference the renamed guest-core asset
  (`opxdemon-guest-core.tar`).
- versionCode **2**, versionName **1.2**.

### Assets
- `OPXdemon-1.2.apk` — the app (debug-signed, sideloadable)

Payloads are unchanged and keep downloading from the **v1.1** release
(`chroot64-debian.tar.gz` for Rooted; `qemu-system-aarch64`, `Image`, `initrd.img`,
`libslirp.so`, `rootfs.imgz` for Rootless).

> For authorized security testing only. You are responsible for complying with all
> applicable laws.
