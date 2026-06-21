#!/usr/bin/env bash
set -euo pipefail

# Build the FINAL (Release) cmux from the latest main and install it into
# /Applications under a personal name + isolated identity, so it runs
# side-by-side with stock cmux without fighting over the shared socket/bundle
# id. Re-run this whenever you want to pick up the latest main.
#
# Usage:
#   ./scripts/install-personal.sh                 # sync main, build, install "crmolinaz-cmux"
#   ./scripts/install-personal.sh --name my-cmux  # custom name
#   ./scripts/install-personal.sh --launch        # open it after install
#   ./scripts/install-personal.sh --no-sync       # build whatever is checked out (skip git)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="crmolinaz-cmux"
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
xcodebuild \
  -project cmux.xcodeproj \
  -scheme cmux \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
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

echo "==> Re-signing"
/usr/bin/codesign --force --deep --sign - --timestamp=none "$DEST" >/dev/null 2>&1 || true

echo "App path:"
echo "  ${DEST}"
if [[ "$LAUNCH" -eq 1 ]]; then
  open "$DEST"
fi
