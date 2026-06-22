#!/usr/bin/env bash
set -euo pipefail

# Build the FINAL (Release) cmux from the latest main and install it into
# /Applications under a personal name + isolated identity, so it runs
# side-by-side with stock cmux without fighting over the shared socket/bundle
# id. Re-run this whenever you want to pick up the latest main.
#
# Usage:
#   ./scripts/install-personal.sh                 # sync main, build, install "T-Rex"
#   ./scripts/install-personal.sh --name my-cmux  # custom name
#   ./scripts/install-personal.sh --launch        # open it after install
#   ./scripts/install-personal.sh --no-sync       # build whatever is checked out (skip git)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="T-Rex"
LAUNCH=0
SYNC=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) APP_NAME="$2"; shift 2 ;;
    --launch) LAUNCH=1; shift ;;
    --no-sync) SYNC=0; shift ;;
    -h|--help)
      grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "error: unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Derive a filesystem/bundle-safe slug from the app name.
SLUG="$(printf '%s' "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed 's/-\{1,\}/-/g; s/^-//; s/-$//')"
[[ -n "$SLUG" ]] || { echo "error: --name must contain alphanumerics" >&2; exit 1; }
BUNDLE_ID="com.cmuxterm.app.personal.${SLUG//-/.}"
DERIVED_DATA="/tmp/cmux-personal-${SLUG}"
BASE_APP_NAME="cmux"
DEST="/Applications/${APP_NAME}.app"

# --- Sync to latest main, without clobbering your working tree -------------
RESTORE_REF=""
restore_branch() {
  if [[ -n "$RESTORE_REF" ]]; then
    git checkout --quiet "$RESTORE_REF" 2>/dev/null || true
    git submodule update --quiet --init --recursive 2>/dev/null || true
  fi
}
if [[ "$SYNC" -eq 1 ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: working tree is dirty. Commit/stash first, or pass --no-sync." >&2
    exit 1
  fi
  CURRENT_REF="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse HEAD)"
  if [[ "$CURRENT_REF" != "main" ]]; then
    RESTORE_REF="$CURRENT_REF"
    trap restore_branch EXIT
  fi
  echo "==> Syncing to latest origin/main"
  git fetch --quiet origin main
  git checkout --quiet main
  git merge --quiet --ff-only origin/main
  git submodule update --quiet --init --recursive
fi

echo "==> Building Release from $(git rev-parse --short HEAD) (${DERIVED_DATA})"
# Build ad-hoc with no entitlements so this works on a machine without an
# Apple Development certificate: the Release config's keychain-access-groups
# entitlement requires a real team prefix that automatic signing can't supply
# here. A personal local build doesn't need it (the Debug build runs the same
# way), and the app is ad-hoc re-signed after the Info.plist edits below.
# Skip the Zig CLI helper build (a Mach-O stub is embedded instead): it
# requires a pinned Zig toolchain that may not be installed locally, and the
# terminal itself runs on the prebuilt GhosttyKit.xcframework. This matches how
# reload.sh builds the app for local use.
xcodebuild \
  -project cmux.xcodeproj \
  -scheme cmux \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CMUX_SKIP_ZIG_BUILD=1 \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_ENTITLEMENTS="" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  build

BUILT="${DERIVED_DATA}/Build/Products/Release/${BASE_APP_NAME}.app"
[[ -d "$BUILT" ]] || { echo "error: build product not found at $BUILT" >&2; exit 1; }

echo "==> Installing to ${DEST}"
# Quit any running instance of this personal app before replacing it.
/usr/bin/osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
pkill -f "${DEST}/Contents/MacOS/${BASE_APP_NAME}" 2>/dev/null || true
sleep 0.3
rm -rf "$DEST"
cp -R "$BUILT" "$DEST"

PL="${DEST}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_NAME}" "$PL" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleName string ${APP_NAME}" "$PL"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_NAME}" "$PL" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string ${APP_NAME}" "$PL"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "$PL"

# Stamp the build with its timestamp so each local build is identifiable in
# T-Rex > About. These personal builds don't auto-update, so the build time is
# the most reliable way to tell which one you're running. CFBundleVersion (the
# "Build" field) becomes a monotonically increasing YYYYMMDD.HHMMSS stamp, and
# the marketing version keeps its number with the stamp appended.
BUILD_TS="$(date +%Y%m%d.%H%M%S)"
SHORT_VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PL" 2>/dev/null || echo 0.0.0)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${SHORT_VER}+build.${BUILD_TS}" "$PL" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${SHORT_VER}+build.${BUILD_TS}" "$PL"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_TS}" "$PL" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${BUILD_TS}" "$PL"
echo "==> Stamped build version ${SHORT_VER}+build.${BUILD_TS}"

# Isolated sockets so this never collides with stock/staging/dev cmux.
APP_SUPPORT_DIR="${HOME}/Library/Application Support/cmux"
CMUXD_SOCKET="${APP_SUPPORT_DIR}/cmuxd-personal-${SLUG}.sock"
CMUX_SOCKET_PATH_VALUE="/tmp/cmux-personal-${SLUG}.sock"
/usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$PL" 2>/dev/null || true
set_env() {
  /usr/libexec/PlistBuddy -c "Set :LSEnvironment:$1 $2" "$PL" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :LSEnvironment:$1 string $2" "$PL"
}
set_env CMUX_BUNDLE_ID "$BUNDLE_ID"
set_env CMUXD_UNIX_PATH "$CMUXD_SOCKET"
set_env CMUX_SOCKET_PATH "$CMUX_SOCKET_PATH_VALUE"

# Custom app icon (terminal with a running T-Rex). Only this personal build gets
# it; stock cmux is untouched. We point the plist at the bundled .icns and drop
# the asset-catalog icon reference so Launch Services uses our file.
ICON_SRC="${REPO_ROOT}/design/trex/AppIcon-trex.icns"
if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "${DEST}/Contents/Resources/AppIcon-trex.icns"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon-trex" "$PL" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon-trex" "$PL"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PL" 2>/dev/null || true
else
  echo "warn: ${ICON_SRC} not found; keeping default icon" >&2
fi

echo "==> Re-signing"
/usr/bin/codesign --force --deep --sign - --timestamp=none "$DEST" >/dev/null 2>&1 || true

# Best-effort: expose a `trex` command on PATH pointing at this build's bundled
# CLI. We deliberately do NOT touch `cmux`, so stock cmux keeps its own command.
# Prefer a user-writable dir already on PATH (no sudo); fall back to a printed
# sudo command for /usr/local/bin.
CLI_SRC="${DEST}/Contents/Resources/bin/cmux"
if [[ -f "$CLI_SRC" ]]; then
  TREX_DIR=""
  for d in "$HOME/.bun/bin" "$HOME/.local/bin" "/opt/homebrew/bin" "/usr/local/bin"; do
    if [[ -d "$d" && -w "$d" ]]; then TREX_DIR="$d"; break; fi
  done
  if [[ -n "$TREX_DIR" ]] && ln -sf "$CLI_SRC" "$TREX_DIR/trex" 2>/dev/null; then
    echo "==> Linked 'trex' -> ${CLI_SRC} (${TREX_DIR}/trex)"
  else
    echo "note: no writable PATH dir for 'trex'. Run this once to finish:" >&2
    echo "  sudo ln -sf \"${CLI_SRC}\" \"/usr/local/bin/trex\"" >&2
  fi
else
  echo "note: bundled CLI not found at ${CLI_SRC}; skipping 'trex' link" >&2
fi

echo "App path:"
echo "  ${DEST}"
if [[ "$LAUNCH" -eq 1 ]]; then
  open "$DEST"
fi
