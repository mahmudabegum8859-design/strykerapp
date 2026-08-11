# OPXdemon

> **OPXdemon 1.2** — a free and open-source mobile pentest suite for Android (authorized testing only).
> Rebranded fork of StrykerOSS by **OP AMINUL FF** (company: **OPX**).

OPXdemon bundles a curated set of network, wireless and web security tools into a single
Android application, exposed through a unified, modern UI. The tooling runs either inside a
Debian trixie (arm64) `chroot` (**Rooted mode**) or inside an arm64 QEMU virtual machine
(**Rootless mode**) — or you can just walk through every screen with **Tour Mode**, which
installs, downloads and executes nothing.

- **Package**: `com.opxdemon`
- **Version**: 1.2 (versionCode 2)
- **Developer**: OP AMINUL FF · **Company**: OPX
- **Min SDK**: 24 (Android 7.0) · **Target SDK**: 28
- **License**: [GNU GPL v3.0](LICENSE) (bundled third-party components keep their own licenses — see in-app *About → Open-source licenses*)

---

## Setup modes

On first launch the installer asks which mode to use:

| Mode | What happens | Requirements |
|---|---|---|
| **Rooted (chroot)** | Downloads and mounts the Debian trixie arm64 chroot from the `chroot-main` release, then runs Nmap, Metasploit, Nuclei, Hydra, SearchSploit, etc. natively on the device. | Rooted device (Magisk/KernelSU recommended), ~1 GB free storage. |
| **Rootless (QEMU)** | Downloads the arm64 VM components (QEMU, kernel, initrd, libslirp, rootfs) from the `rootless-main` release and boots the same Debian toolset in a VM — no root required. | arm64 device, ~2 GB free storage; optional monitor-mode USB Wi-Fi adapter is passed into the VM. |
| **Tour Mode** | No root, no VM, no downloads, no extraction. Every screen and button opens with a view-only walkthrough — nothing is installed or executed on the device. | None. |

### Payload release sources

The app pulls its engine payloads from these upstream release tags (kept as-is by design):

- Rooted mode → `https://github.com/zalexdev/strykerapp/releases/tag/chroot-main`
  (`chroot64-debian.tar.gz`, plus the legacy Alpine tarballs read by older builds)
- Rootless mode → `https://github.com/zalexdev/strykerapp/releases/tag/rootless-main`
  (`qemu-system-aarch64`, `Image`, `initrd.img`, `libslirp.so`, `rootfs.imgz`)

The OTA manifest (`opxdemon_manifest.json`) is fetched from this repository's `main` branch,
so pushing a new manifest + release makes the app update automatically.

---

## Capabilities

| Module | Description |
|---|---|
| **Dashboard** | Live overview of the engine, USB adapters, mounted state and quick actions. |
| **WiFi networks** | Scan, deauth, handshake capture, WPS attacks (Pixie Dust, common pins, custom pins) via external monitor-mode adapters. |
| **Handshakes** | Local handshake storage with rename, share, export to OnlineHashCrack and on-device cracking via Hashcat. |
| **MAC changer** | Inline + dedicated MAC randomizer with persistent profiles. |
| **WhisperPair (BLE)** | Fast Pair device discovery, CVE-2025-36911 vulnerability check and exploit chain, post-pair account-key write and HFP audio capture/passthrough. |
| **Local network** | Nmap host discovery, port scans, OS fingerprinting, per-device exploit dispatch with a live terminal. |
| **Nmap** | Direct Nmap interface with custom scripts, NSE, and exported reports. |
| **Web scanner (Nuclei)** | Multi-target Nuclei scans with severity-grouped findings. |
| **Arsenal** | Custom exploit / scanner database with template arguments (`{IP}`, `{PORT}`, `{MAC}`, `{GW}`, `{MASK}`). |
| **HID Attacks** | DuckyScript-compatible USB HID injection with 7 keyboard layouts and a live execution log. |
| **USB Arsenal** | USB-gadget profile manager — HID keyboard/mouse, mass-storage, RNDIS/ECM/ACM functions, `.img`/`.iso` mounts. |
| **Metasploit** | Native MSF console inside the chroot/VM with sessions, payload generation and module browser. |
| **GeoMac** | OSM-based map of captured BSSIDs / handshakes with WiGLE-style export (KML/CSV). |
| **VNC desktop** | Stand-up an in-chroot XFCE session and view it locally. |
| **Core manager** | Mount / unmount / repair the engine, manage installed components. |

---

## Build

Standard Android Gradle build. JDK 17, SDK platform 33, build-tools 34.0.0, NDK 25.1.8937393, CMake 3.22.1.

```bash
# Debug APK (unsigned)
sh ./gradlew assembleDebug

# Release APK (R8-minified; unsigned unless signing env vars are set)
sh ./gradlew assembleRelease

# Install on a connected device
sh ./gradlew installDebug

# Lint
sh ./gradlew lint
```

Output APKs land in `app/build/outputs/apk/`.

### Release signing (environment variables)

Generate the keystore once:

```bash
keytool -genkeypair -v -keystore opxdemon-release.jks \
  -storepass 90df9903fa04c6194713104c28ffe648 \
  -keypass 27f0565807069b2ed0de7aaa03fb05c2 \
  -alias opxdemon -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=OP AMINUL FF, O=OPX, C=BD"
```

Then provide these values via the Freebuff **API Keys** tab, `~/.gradle/gradle.properties`,
`-P` flags, or environment (**rotate the passwords if this repo is public**):

| Variable | Value |
|---|---|
| `OPXDEMON_RELEASE_STORE_FILE` | path to `opxdemon-release.jks` |
| `OPXDEMON_RELEASE_STORE_PASSWORD` | `90df9903fa04c6194713104c28ffe648` |
| `OPXDEMON_RELEASE_KEY_ALIAS` | `opxdemon` |
| `OPXDEMON_RELEASE_KEY_PASSWORD` | `27f0565807069b2ed0de7aaa03fb05c2` |

If the variables are not set, the release build is left unsigned so CI / contributors can still
produce an APK.

---

## Installation (end users)

1. Install the APK on a rooted (or rootless-capable) device: `adb install OPXdemon-1.2.apk`.
2. First launch: pick **Rooted**, **Rootless**, or **Tour Mode**.
   - Rooted: the in-app installer downloads and mounts the Debian chroot, then installs optional
     components (Metasploit, Nuclei, Hydra, SearchSploit).
   - Rootless: the installer downloads the VM components and boots the guest.
   - Tour: the app opens immediately in view-only mode.
3. Plug in a supported USB Wi-Fi adapter for monitor-mode features.

---

## Notes on preserved paths

The chroot now mounts at `/data/local/opxdemon` (host side). Two low-level names are kept
as-is because they are baked into the prebuilt payloads this app downloads:

- `/sdcard/Stryker` — the path the chroot/VM guest uses for captures, wordlists and payloads.
  On the host it is backed by the visible `/sdcard/OPXDemon` folder (bound in by `bootroot`),
  so nothing user-facing shows the old name.
- Guest-side binaries `stryker-agentd` / `stryker-ptyd` inside the downloaded rootfs.

Rebranding those requires rebuilt payloads and is not user-visible.

---

## License

OPXdemon is free software under the **GNU General Public License v3.0** (see [`LICENSE`](LICENSE)).
It is a rebranded fork of [StrykerOSS](https://github.com/zalexdev/strykerapp) by zalexdev
(© 2021–2026); upstream attribution and the bundled third-party notices in
[`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md) are preserved.

## Disclaimer

OPXdemon is provided **for authorized security testing, education and research only**. You are
responsible for complying with all applicable laws and obtaining explicit permission before
testing any system or device you do not own. The authors accept no liability for misuse.
