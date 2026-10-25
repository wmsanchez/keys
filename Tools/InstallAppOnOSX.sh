#!/bin/sh
set -eu

if [ "${CONFIGURATION:-}" != "Debug" ]; then
    echo "Skipping VSCOKeys app install for ${CONFIGURATION:-unknown} configuration."
    exit 0
fi

if [ "${CI:-}" = "true" ] || [ "${CI:-}" = "1" ]; then
    echo "Skipping VSCOKeys app install in CI."
    exit 0
fi

if [ "${VSCO_KEYS_AUTO_INSTALL:-YES}" != "YES" ]; then
    echo "Skipping VSCOKeys app install (VSCO_KEYS_AUTO_INSTALL is disabled)."
    exit 0
fi

source_app="${TARGET_BUILD_DIR:?}/${FULL_PRODUCT_NAME:?}"
destination_app="/Applications/${FULL_PRODUCT_NAME}"

if [ ! -d "$source_app" ]; then
    echo "Built app not found: $source_app" >&2
    exit 1
fi

stage_dir=$(/usr/bin/mktemp -d "/Applications/.VSCOKeys.install.XXXXXX")
staged_app="$stage_dir/$FULL_PRODUCT_NAME"
previous_app="$stage_dir/previous.app"

cleanup() {
    if [ -d "$previous_app" ] && [ ! -e "$destination_app" ]; then
        /bin/mv "$previous_app" "$destination_app" || true
    fi
    /bin/rm -rf "$stage_dir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

/usr/bin/ditto "$source_app" "$staged_app"
/usr/bin/killall VSCOKeys >/dev/null 2>&1 || true

layout_dir="$HOME/Library/Application Support/VSCOKeys"
if [ -d "$layout_dir" ]; then
    backup_root="$HOME/Library/Application Support/VSCOKeys Backups"
    /bin/mkdir -p "$backup_root"
    backup_dir="$backup_root/VSCOKeys-$(/bin/date +%Y%m%d-%H%M%S)-$$"
    /usr/bin/ditto "$layout_dir" "$backup_dir"
    echo "Backed up VSCO Keys data to $backup_dir"
fi

if [ -e "$destination_app" ]; then
    /bin/mv "$destination_app" "$previous_app"
fi

/bin/mv "$staged_app" "$destination_app"
echo "Installed $destination_app"