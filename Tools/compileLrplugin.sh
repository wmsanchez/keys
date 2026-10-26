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
fi
