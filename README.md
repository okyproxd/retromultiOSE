# Retro MultiOSE

<p align="center">
  <img src="screenshots/app-icon-concept.png" width="200" alt="Retro MultiOSE icon concept" />
</p>

<p align="center">
  <strong>A native macOS front-end for running vintage Mac OS, Mac OS X, and Windows XP side by side.</strong><br/>
  Built on QEMU, Basilisk II, and SheepShaver — one clean SwiftUI app, four emulation backends, real save states.
</p>

<p align="center">
  <strong>Version 0.1.0</strong> — early release, see <a href="#known-issues">Known Issues</a> below.
</p>

---

## What is this?

Retro MultiOSE is a SwiftUI macOS app that orchestrates classic emulators — QEMU, Basilisk II, and SheepShaver — behind one polished interface. Instead of juggling separate apps, config files, and command-line flags for each system you want to run, you get:

- A **Setup** tab to import ROMs, boot CDs/installers, and hard disks
- A **Machines** tab to configure and launch virtual machines per OS
- Real, working **Save States** (name them, load them, resume instantly)
- Adjustable CPU speed presets per backend
- A RAM field that goes from 128 KB (real Mac 128K territory) up to 8 GB

## Screenshots

<p align="center">
  <img src="screenshots/three-os-hero-shot.png" width="800" alt="Windows XP, Mac OS X 10.5 Leopard, and Mac OS 9.1 running simultaneously" /><br/>
  <em>Windows XP, Mac OS X 10.5 Leopard, and Mac OS 9.1 — all running at once, side by side.</em>
</p>

<p align="center">
  <img src="screenshots/machines-tab.png" width="45%" alt="Machines tab" />
  <img src="screenshots/setup-tab.png" width="45%" alt="Setup tab" />
</p>

## Supported systems

| System | Backend | Status |
|---|---|---|
| Windows XP | QEMU (x86_64) | ✅ Fully working — installs, boots, snapshots |
| Mac OS X 10.0–10.5 | QEMU (PowerPC) | ✅ Fully working — Leopard confirmed installed & booted |
| Mac OS 9.x (New World) | QEMU (PowerPC) | ✅ Fully working — no ROM required, boots via Open Firmware |
| System 6 / 7.x (68k) | Basilisk II | 🟡 Boots partway, hangs a few seconds in — see Known Issues |
| Mac OS 8.5–9.0.4 (Old World/New World) | SheepShaver | 🟡 ROM-dependent — see Known Issues |

## Known Issues

This is an early release built over one very long debugging session. Being upfront about what isn't solid yet:

**Basilisk II (68k Macs, System 6/7.x)**
Basilisk II reliably reads valid ROMs and disk images, but consistently hangs (high CPU, beachball) a few seconds into boot on Apple Silicon. This reproduces across different ROMs and disks, and isn't fixed by the documented `ignoresegv`/`idlewait`/`jit false` stability flags (already applied in this build). Root cause looks like an Apple Silicon–specific issue in Basilisk II's aging, mostly-unmaintained codebase (last active development ~2006) rather than anything in this app's configuration. Not yet resolved.

**SheepShaver (Mac OS 8.5–9.0.4)**
SheepShaver requires a real Old World or New World Power Mac ROM. Two hard constraints to know before you try:
- **Blue & White G3 ROMs are not supported by SheepShaver at all** — this is a documented upstream limitation, not a config issue. A Beige G3, or ROMs from the Power Mac 6100/7200/7500/8500/9500 family, are known to work.
- SheepShaver's real supported OS ceiling is **Mac OS 9.0.4** — later 9.1–9.2.2 aren't supported because SheepShaver doesn't emulate an MMU.
- **If you just want classic Mac OS 9.x working, skip SheepShaver — use QEMU (PowerPC) instead.** It boots OS 9.0–9.2.2 directly via Open Firmware, no ROM dump needed at all, and is fully working in this build.

**Multi-disk machines**
Right now each machine supports one boot CD + one hard disk, configured at creation time. There's no in-app way yet to attach a second hard disk (e.g. a software/utility disk alongside your main OS disk) to an existing machine.

**Quitting the app kills running VMs**
QEMU/Basilisk/SheepShaver run as child processes of the app. Quitting Retro MultiOSE (or a crash) terminates any running machines — there's no "detach and keep running in background" yet.

## Installation

1. Download the latest `.dmg` from [Releases](../../releases)
2. Open it, drag **Retro MultiOSE.app** to Applications
3. First launch: right-click the app → **Open** (it's unsigned/ad-hoc — see [Licensing](#licensing) for why)
4. Go to **Setup** and import your own ROM/firmware files and disk images — see [Getting media](#getting-media) below

## Getting media

**This app does not include or link to any copyrighted Apple or Microsoft software.** You need to supply your own:

- **ROM/firmware files** — dumped from real vintage Mac hardware you own, using tools like BlueSCSI-based dumpers or utilities from the 68kmla.org community
- **OS installer/boot disk images** — imaged from discs you own via **Disk Utility → File → New Image → Image from [disc] → DVD/CD master format**. This specific format matters — a plain/generic rip often strips the Apple Partition Map and HFS boot structure needed to actually boot.

## Building from source

### 1. Compile the backends

```bash
./Scripts/build_qemu.sh
```

This builds `qemu-system-ppc`, `qemu-system-x86_64`, and `qemu-img` with HVF-ready flags. It'll ask for Homebrew dependencies along the way.

Basilisk II and SheepShaver are built separately from the same source tree:

```bash
git clone https://github.com/kanjitalk755/macemu.git /tmp/macemu
cd /tmp/macemu/BasiliskII/src/Unix && ./autogen.sh && ./configure && make
cd /tmp/macemu/SheepShaver/src/Unix && ./autogen.sh && ./configure && make
```

> **Note on Apple Silicon + newer Xcode toolchains:** you will likely hit `-std=gnu23` incompatibility errors in Basilisk II/SheepShaver's Makefiles (they predate modern C/C++ standard defaults). Fix by patching the Makefile's `CC`/`CPP` variables to force `gnu99`/`gnu++17` as needed — see this project's issue history for the exact `sed` commands used.

### 2. Bundle the binaries

Copy all five binaries (`qemu-system-ppc`, `qemu-system-x86_64`, `qemu-img`, `BasiliskII`, `SheepShaver`) plus QEMU's `share/` firmware folder into:

```
RetroMultiOSE/Resources/qemu/
```

### 3. Add to Xcode

- Add the `qemu` folder via **File → Add Files** → **"Create folder references"** (blue folder icon)
- If `qemu-img` specifically doesn't show up in the built app's `Contents/Resources/` after a Clean Build Folder + rebuild, add it a second time as a **standalone individual file reference** — this was a real, reproducible issue where the folder reference didn't reliably pick up files added after the initial folder was added.
- Check **Build Phases → Compile Sources** for any stray firmware files (e.g. `skiboot.lid`) that got miscategorized as source code — remove them from that list if present.

### 4. Build and run

⌘B, ⌘R. First launch, go to Setup and import your own media.

## Creating the .dmg for release

Once your build is working (Debug or a signed Release build):

```bash
# Archive first via Xcode: Product → Archive → Distribute App → Copy App
# This gives you a clean, standalone RetroMultiOSE.app

brew install create-dmg

create-dmg \
  --volname "Retro MultiOSE" \
  --window-size 600 400 \
  --icon-size 100 \
  --app-drop-link 450 150 \
  "RetroMultiOSE.dmg" \
  "path/to/exported/RetroMultiOSE.app"
```

Upload the resulting `RetroMultiOSE.dmg` to your GitHub repo's **Releases** page.

## Licensing

This app bundles **QEMU, Basilisk II, and SheepShaver**, all GPL-licensed. That means:

- This repo is licensed **GPLv2 or later** to stay compatible
- **This cannot be distributed via the Mac App Store** — Apple's App Store terms conflict with GPL requirements. GitHub Releases (as done here) is the standard distribution path for GPL-bundling emulator front-ends — this is the same reason UTM isn't on the App Store either.
- The app ships **unsigned/ad-hoc** — users will see a Gatekeeper warning on first launch and need to right-click → Open once.

No Apple or Microsoft copyrighted software (ROMs, OS installers) is included in this repo or any release. See [Getting media](#getting-media).

## Architecture notes

- SwiftUI, no external Swift dependencies
- `LibraryStore` manages ROM/disk file storage under `~/Library/Application Support/RetroMultiOSE/`
- `EmulatorController` builds backend-specific launch arguments and manages the child process + QEMU monitor socket (for save states)
- `EmulatorProcessManager` keeps one controller alive per machine, independent of SwiftUI view lifecycle, so switching between machines doesn't lose track of ones still running
- Save states use QEMU's native `savevm`/`loadvm` — **requires qcow2-format disks**; raw `.img` disks cannot snapshot (a hard QEMU limitation, not fixable in this app)

## Contributing

Issues and PRs welcome, especially on the two known-broken backends (Basilisk II Apple Silicon hang, SheepShaver New World ROM compatibility) or the multi-disk machine gap.

## Current build platform note

Bundled binaries in this build are compiled for **Apple Silicon (arm64)** only. Intel Mac support would require a separate cross-compiled binary set.
