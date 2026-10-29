#
#  VSCO Keys for Adobe Lightroom
#  Copyright (C) 2015 Visual Supply Company
#  Licensed under GNU GPLv2 (or any later version).
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$PROJECT_DIR/VSCOKeys.lrdevplugin"
PLUGIN_DIR="$PROJECT_DIR/Build/VSCOKeys.lrplugin"

cp "$PROJECT_DIR/VSCOKeys/VSCOKeys/CommandCategories.json" "$SOURCE_DIR/CommandCategories.json"
mkdir -p "$PLUGIN_DIR"
mkdir -p "$SOURCE_DIR/apps"

# Remove old app bundle from source to avoid copy errors
if [ -d "$SOURCE_DIR/apps/VSCOKeys.app" ]; then
	echo "Removing old app bundle from source..."
	rm -rf "$SOURCE_DIR/apps/VSCOKeys.app"
fi

# Also remove from build directory to avoid rsync conflicts
if [ -d "$PLUGIN_DIR/apps/VSCOKeys.app" ]; then
	echo "Removing old app bundle from build..."
	rm -rf "$PLUGIN_DIR/apps/VSCOKeys.app"
fi

# Copy the built app to the plugin's apps directory for auto-launch
# App should be in Build/ for both Debug and Release builds
APP_FOUND=0
APP_SOURCE="$PROJECT_DIR/Build/VSCOKeys.app"

if [ -d "$APP_SOURCE" ]; then
	APP_FOUND=1
fi

if [ "$APP_FOUND" -eq 1 ]; then
	echo "Copying VSCOKeys.app from $APP_SOURCE..."
	cp -R "$APP_SOURCE" "$SOURCE_DIR/apps/"
else
	echo "Warning: VSCOKeys.app not found at $APP_SOURCE"
	echo "Plugin will not auto-launch. Run 'make build' or 'make build-release' first."
fi

rsync -a --delete --delete-excluded \
	--exclude='*.log' \
	--exclude='skey.key' \
	"$SOURCE_DIR/" "$PLUGIN_DIR/"

INSTALLED_PLUGIN_DIR="$HOME/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin"
if [ -d "$INSTALLED_PLUGIN_DIR" ]; then
	rsync -a \
		--exclude='*.log' \
		--exclude='skey.key' \
		"$SOURCE_DIR/" "$INSTALLED_PLUGIN_DIR/"
	echo "Updated installed Lightroom plugin: $INSTALLED_PLUGIN_DIR"
else
	echo "Warning: Lightroom plugin directory not found: $INSTALLED_PLUGIN_DIR"
	echo "Plugin compiled to $PLUGIN_DIR but not synced to Lightroom."
	echo "Ensure Lightroom Classic is installed and run again after first launch."
fi
