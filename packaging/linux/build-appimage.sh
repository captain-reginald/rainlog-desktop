#!/usr/bin/env bash
# Build a self-contained x86-64 AppImage for Rain Log.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 VERSION" >&2
  echo "example: $0 1.0.0" >&2
  exit 2
fi

VERSION="$1"
VERSION="${VERSION#v}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$ROOT/build/appimage-work"
TOOLS_DIR="$ROOT/build/appimage-tools"
APP_DIR="$WORK_DIR/RainLog.AppDir"
BUILD_DIR="$WORK_DIR/build"
OUT_DIR="$ROOT"

rm -rf "$WORK_DIR"
mkdir -p "$APP_DIR" "$BUILD_DIR" "$TOOLS_DIR"

download_tool() {
  local file="$1"
  local url="$2"
  if [[ ! -x "$TOOLS_DIR/$file" ]]; then
    echo "Downloading $file"
    curl -fL --retry 3 --retry-delay 2 -o "$TOOLS_DIR/$file" "$url"
    chmod +x "$TOOLS_DIR/$file"
  fi
}

download_tool linuxdeploy-x86_64.AppImage \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
download_tool linuxdeploy-plugin-qt-x86_64.AppImage \
  https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage

QMAKE_BIN="${QMAKE:-}"
if [[ -z "$QMAKE_BIN" ]]; then
  if [[ -n "${QT_ROOT_DIR:-}" && -x "$QT_ROOT_DIR/bin/qmake" ]]; then
    QMAKE_BIN="$QT_ROOT_DIR/bin/qmake"
  elif command -v qmake6 >/dev/null; then
    QMAKE_BIN="$(command -v qmake6)"
  elif command -v qmake >/dev/null; then
    QMAKE_BIN="$(command -v qmake)"
  else
    echo "error: could not find qmake (set QMAKE or QT_ROOT_DIR)" >&2
    exit 1
  fi
fi
export QMAKE="$QMAKE_BIN"
export QML_SOURCES_PATHS="$ROOT/qml:$ROOT/shared"
# linuxdeploy's bundled strip does not understand modern RELR ELF sections.
export NO_STRIP="${NO_STRIP:-1}"
# Bundle native Wayland support as well as Linux's default XCB platform.
export EXTRA_PLATFORM_PLUGINS="${EXTRA_PLATFORM_PLUGINS:-libqwayland.so}"
export EXTRA_QT_MODULES="${EXTRA_QT_MODULES:-waylandcompositor}"
# Useful on CI machines without FUSE available.
export APPIMAGE_EXTRACT_AND_RUN="${APPIMAGE_EXTRACT_AND_RUN:-1}"

cmake -S "$ROOT" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${QT_ROOT_DIR:-${CMAKE_PREFIX_PATH:-}}" \
  -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "$BUILD_DIR" --parallel "$(nproc)"
cmake --install "$BUILD_DIR" --prefix "$APP_DIR/usr"

(
  cd "$WORK_DIR"
  "$TOOLS_DIR/linuxdeploy-x86_64.AppImage" \
    --appdir "$APP_DIR" \
    --executable "$APP_DIR/usr/bin/rainlog" \
    --desktop-file "$ROOT/packaging/rainlog.desktop" \
    --icon-file "$ROOT/packaging/rainlog.png" \
    --plugin qt \
    --custom-apprun "$ROOT/packaging/linux/AppRun"

  # appimagetool expects a PNG at the root when the desktop file uses
  # Icon=rainlog. linuxdeploy otherwise chooses the installed SVG, which
  # appimagetool does not accept as a .DirIcon source.
  png_icon="$(find "$APP_DIR/usr/share/icons" -path '*/apps/rainlog.png' -type f -print -quit)"
  cp "$png_icon" "$APP_DIR/rainlog.png"

  "$TOOLS_DIR/linuxdeploy-x86_64.AppImage" \
    --appdir "$APP_DIR" \
    --output appimage

  generated="$(find "$WORK_DIR" -maxdepth 1 -type f -name '*.AppImage' -print -quit)"
  out="$OUT_DIR/RainLog-v${VERSION}-linux-x86_64.AppImage"
  rm -f "$out" "$out.sha256"
  mv "$generated" "$out"
  chmod 755 "$out"
  sha256sum "$out" > "$out.sha256"
  echo "Built $out"
)
