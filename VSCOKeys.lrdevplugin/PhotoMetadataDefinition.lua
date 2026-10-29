--[[----------------------------------------------------------------------------

PhotoMetadataDefinition.lua
Custom metadata definition for aspect ratio and color profile filtering

------------------------------------------------------------------------------

VSCO Keys for Adobe Lightroom
Copyright (C) 2015 Visual Supply Company
Licensed under GNU GPLv2 (or any later version).

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

------------------------------------------------------------------------------]]

return {

	metadataFieldsForPhotos = {

		-- Aspect Ratio field (string for filtering)
		{
			id = 'aspectRatio',
			version = 1,
			title = LOC "$$$/VSCOKeys/Metadata/AspectRatio=Precise Aspect Ratio",
			dataType = 'string',
			browsable = true,
			searchable = true,
		},

		-- Base Color Profile field (string for camera calibration profile)
		{
			id = 'baseColorProfile',
			version = 1,
			title = LOC "$$$/VSCOKeys/Metadata/BaseColorProfile=Base Color Profile",
			dataType = 'string',
			browsable = true,
			searchable = true,
		},

		-- LUT Color Profile field (string for applied Look/Profile)
		{
			id = 'lutColorProfile',
			version = 1,
			title = LOC "$$$/VSCOKeys/Metadata/LUTColorProfile=LUT Color Profile",
			dataType = 'string',
			browsable = true,
			searchable = true,
		},

		-- Look Amount field (string for Look intensity)
		{
			id = 'lookAmount',
			version = 1,
			title = LOC "$$$/VSCOKeys/Metadata/LookAmount=Look Amount",
			dataType = 'string',
			browsable = true,
			searchable = true,
		},
	},

	schemaVersion = 10,

	updateFromEarlierSchemaVersion = function( catalog, previousSchemaVersion )
		-- Schema migration - clear old data on version changes
	end,

}
