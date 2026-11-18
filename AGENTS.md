# AGENTS.md

Guidance for coding agents working in this repository. Read this before
changing anything.

## What this project is

**Rain Log Desktop** is a small, windowed companion to the
[Omarchy Rain Log plugin](https://github.com/captain-reginald/omarchy-rain-log)
(`io.github.captain-reginald.rainlog`). It shows the same card the plugin bar
widget opens — same layout, same controls, same rainfall file — packaged as a
normal application so it also runs outside Hyprland and on Windows 10 x64.

- One Qt 6 / Qt Quick codebase, CMake build, shared QML UI for both platforms.
- Two separate published products: the Omarchy plugin (separate repo) and this
  desktop app. This repository is **Rain Log Desktop only** — it is not a
  branch of the plugin repo, and plugin users install from the plugin repo.
- A third product, **Rain Log Server**, lives in separate repositories and is
  not covered here.

## Hard constraints

These are non-negotiable. Violating them corrupts user data or the plugin.

1. **Never modify the plugin repository from here.** The plugin
   (`omarchy-rain-log`) is a separate, published product. Data-format and UI
   compatibility is achieved in this repo, not by editing the plugin.
2. **Never write to `~/Documents/rainlog/rainlog.json` except through the
   app's own store code** (`src/store.cpp`). It is the user's live rainfall
   data (tenths of an inch, keyed by local date) and is synced via Syncthing.
   - Do not "fix" the file by hand, do not run formatters on it, do not
     round-trip it through a quick script.
   - Writes must stay atomic and two-space JSON; an untouched file must never
     be rewritten (this is intentional Syncthing-friendly behavior).
   - The folder contains Syncthing metadata and backups — never delete or
     rewrite anything in `~/Documents/rainlog/`.
3. **The data folder name stays `rainlog`** (`~/Documents/rainlog/`, or the
   Documents folder on Windows). Only packaging/manifest/binary naming uses
   "Rain Log Desktop".
4. **Settings are deliberately separate from data.** App settings live in
   `~/.config/rainlog-desktop/config.json` (Linux) /
   `%APPDATA%\rainlog-desktop\config.json` (Windows). Do not move them into
   the rainfall folder.
5. **Never edit `/usr/share/omarchy/`** and never change the plugin's
   `settingsMode` / `historyMode` defaults (they stay `false`) or its bar
   integration.
6. **Do not run the app against the real data folder in tests.** Use
   `QT_QPA_PLATFORM=offscreen`, `--screenshot`, and a throwaway `HOME` /
   `XDG_DATA_HOME` when you need a sandbox.
7. **Releases are cut from `main`** via `v1.0.*` tags; day-to-day work happens
   on `dev`. Do not push release tags from `dev`.

## Branding rules

- The app's product/display name is **Rain Log Desktop**: desktop file,
  installer, shortcuts, Apps & Features entry, AppImage filename, docs,
  `--help` text, `applicationDisplayName`.
- The **window title stays `Rain Log`**.
- The executable is `rainlog-desktop`; the desktop ID, Wayland/X11
  `StartupWMClass`, Hyprland float rule, AppImage name, and icon base name are
  all `rainlog-desktop`.
- The QML module URI stays `RainLog` and singletons/classes keep their names.
- Published artifact names:
  `RainLog-Desktop-v{VERSION}[-dev{N}]-{linux-x86_64.AppImage|windows-x64.exe}`

## Repository layout

```text
src/                 C++ host: entry point, store, config, theme source, CLI,
                     --install/--uninstall, single-instance IPC
qml/Main.qml         Desktop host window: frameless, title strip (gear,
                     minimize, close), resize edges; all host chrome lives here
shared/ui/           Shared card UI (RainLogContent.qml, Theme.qml, controls)
shared/model/        Shared JS model (Model.js)
packaging/           AppImage (linux/), NSIS installer (windows/), desktop
                     file, icons, AppStream metainfo, Qt icon resources, fonts
.github/workflows/   linux-appimage.yml, windows-installer.yml
docs/                Screenshots and release notes
CMakeLists.txt       Project version + RAINLOG_VERSION_SUFFIX cache var
```

Layering rules:

- `shared/` must stay host-agnostic — no window chrome, no host-specific
  paths, no desktop-only assumptions.
- Host chrome and window behavior belong in `qml/Main.qml` / `src/`.
- The plugin carries its own copy of the shared UI. If you change shared UI
  behavior in a way that should apply to both clients, mirror it in the plugin
  repo deliberately — never silently diverge the two.

## Build and test

Requires CMake ≥ 3.21 and Qt 6.5+ (Core, Gui, Quick; CI uses 6.8.3).

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/rainlog-desktop --version
```

Useful checks:

```bash
# Offscreen smoke test / docs screenshot
QT_QPA_PLATFORM=offscreen ./build/rainlog-desktop --view main \
  --screenshot /tmp/opencode/screenshot.png

# Qt lint
qmllint qml/Main.qml shared/ui/*.qml

# Sandboxed menu install/uninstall test
HOME=/tmp/opencode/test XDG_DATA_HOME=/tmp/opencode/test/share \
  ./build/rainlog-desktop --install
```

Linux AppImage:

```bash
packaging/linux/build-appimage.sh 1.0.1   # locally; prefer CI artifacts
```

Locally built AppImages link against the local glibc (Arch produces glibc
newer than what Linux Mint provides) and **do not run everywhere**. CI builds
on `ubuntu-22.04`; treat the CI artifact as the only test vehicle for
release-like Linux packages.

Windows builds are produced by GitHub Actions on `windows-2022` with Qt
6.8.3 / MSVC 2022 x64; there is no supported local Windows build path in this
workflow. The installer is all-users, unsigned, bundles the VC++ redistributable,
and requires Windows 10 x64.

## CI and release process

Both workflows trigger **only** on pushes to `dev`, tags matching `v1.0.*`, and
`workflow_dispatch`. They no longer run on every `v*` tag.

- Dev builds (branch `dev`) resolve the version as `CMakeLists.txt` base +
  `-dev$(git rev-list --count HEAD)`, e.g. `1.0.1-dev31`.
- The suffix is injected into the app via `-DVERSION_SUFFIX=...` →
  `RAINLOG_VERSION_SUFFIX` → `RAINLOG_VERSION` compile definition, so
  `--version` always matches the artifact.
- Release builds (any non-`dev` ref, e.g. a `v1.0.*` tag on `main`) carry no
  suffix.

Release checklist:

1. Push to `dev`; wait for both workflows to go green; download the artifacts
   and smoke-test them.
2. Merge `dev` → `main`.
3. Tag `v1.0.x` on `main`; the tag push rebuilds both platforms with clean
   names.
4. Draft the GitHub release from the tag; attach the Linux AppImage and the
   Windows installer (the workflow artifacts). Releases are public.
5. Known accepted limitations: Windows installer is unsigned (SmartScreen
   warning), no installer signing certificate yet; do not claim otherwise in
   release notes.

`v1.0.0` is already published with a Linux AppImage (CI-built) and Windows
installer (an older binary). Expect `v1.0.1` to supersede both from `main`.

## Behavioral contract to preserve

- Frameless window sized like the plugin card; slim title strip carries
  settings gear (left of the window controls) and minimize/close; the strip
  drags the window. No tray, no daemon, no bar menu, no CLI bar mode.
- Window shrinks to fit content when switching views; user resizing pins it.
- On Hyprland the app is intended to float; it must still behave acceptably
  when tiled (compositor can resize it).
- Single instance per user session; a second launch raises the running window
  and exits. Socket name: `rainlog-desktop-<sanitized-user>`.
- Data store: reads/writes the same JSON as the plugin, watched for external
  (Syncthing) updates, atomic writes, two-space indentation.
- Live theme following on Omarchy; bundled palette fallback elsewhere.
- Close button saves and quits; closing never discards unsaved edits.

## Common pitfalls

- **Version drift**: bump `project(... VERSION ...)` in `CMakeLists.txt` and
  the `FILEVERSION` / `VS_VERSION_INFO` numbers in
  `packaging/windows/rainlog-desktop.rc` together. The workflow only reads
  `CMakeLists.txt`.
- **NSIS**: keep `SetShellVarContext all` out of file scope on new sections
  if you change shortcut paths — it is set once for the installer and once in
  the uninstaller; mismatched contexts silently target the wrong profile.
- **linuxdeploy**: do not strip RELR sections (`NO_STRIP=1` is intentional);
  the bundled strip cannot parse them.
- **AppRun**: must exec `usr/bin/rainlog-desktop` by path, not a symlink —
  Qt resolves plugin paths from argv[0].
- **Icon renames**: `app_icon.qrc` aliases, `main.cpp` icon fallback,
  `--install`/`--uninstall` copy sources, desktop file `Icon=`, and the
  AppImage root PNG must all stay consistent (`rainlog-desktop`).
- **SHA-256**: release assets ship a `.sha256` sibling; keep the workflow
  naming consistent if you rename artifacts.

## Before you finish

- `grep -RInE 'rainlog|RainLog|Rain Log' --exclude-dir=.git --exclude-dir=build .`
  — confirm no stale `rainlog` references crept in outside the intentional
  compatibility surface (data folder, bundle IDs, plugin links, `QML URI`).
- If you touched shared UI behavior, say so explicitly in your summary — the
  plugin repo likely needs the same change.
- If you changed anything under `~/Documents/rainlog/`, report it loudly.
  You should not have.
