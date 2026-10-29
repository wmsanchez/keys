--[[----------------------------------------------------------------------------

UpdatePhotoMetadata.lua
Utility to calculate and update custom metadata for selected photos

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

local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrProgressScope = import 'LrProgressScope'
local LrApplication = import 'LrApplication'
local LrFunctionContext = import 'LrFunctionContext'
local LrDevelopController = import 'LrDevelopController'
local logging = require "Logging.lua"

-- Calculate aspect ratio from dimensions
-- Returns the standardized ratio string (e.g., "3:2", "16:9", "other")
local function calculateAspectRatioString( width, height )
	if width == nil or height == nil or width == 0 or height == 0 then
		return "original"
	end

	-- Normalize to ratio >= 1.0
	local ratio = math.max( width, height ) / math.min( width, height )

	-- Match against standard ratios with tolerance
	local tolerance = 0.01

	local standardRatios = {
		{ value = "1:1", ratio = 1.0 },
		{ value = "4:3", ratio = 4/3 },
		{ value = "3:2", ratio = 3/2 },
		{ value = "5:4", ratio = 5/4 },
		{ value = "16:9", ratio = 16/9 },
		{ value = "2:1", ratio = 2.0 },
		{ value = "21:9", ratio = 21/9 },
	}

	for _, standard in ipairs( standardRatios ) do
		if math.abs( ratio - standard.ratio ) <= tolerance then
			return standard.value
		end
	end

	return "other"
end

-- Calculate orientation from dimensions (removed - Lightroom provides this)

-- Main function to update metadata for selected photos
local function updateMetadataForSelectedPhotos()

	logging:log("UpdatePhotoMetadata: Starting...")

	local catalog = LrApplication.activeCatalog()
	local targetPhotos = catalog.targetPhotos

	logging:log("UpdatePhotoMetadata: Found " .. (targetPhotos and #targetPhotos or 0) .. " selected photos")

	if not targetPhotos or #targetPhotos == 0 then
		LrDialogs.message( "No photos selected", "Please select one or more photos to update metadata." )
		return
	end

	-- Create a progress scope for the native progress bar
	local progressScope = LrProgressScope {
		title = "Updating Photo Metadata",
		cancelable = false,
	}

	-- Collect all metadata first
	local metadataUpdates = {}
	local errorCount = 0
	local errorMessages = {}
	local totalPhotos = #targetPhotos

	for i, photo in ipairs( targetPhotos ) do
		logging:log("UpdatePhotoMetadata: Processing photo " .. i)

		-- Update progress
		progressScope:setPortionComplete( i, totalPhotos )

		-- Yield periodically to prevent blocking
		if i % 5 == 0 then
			LrTasks.yield()
		end

		-- Get dimensions
		local rawMetadata = photo:getRawMetadata( 'dimensions' )
		local croppedMetadata = photo:getRawMetadata( 'croppedDimensions' )

		-- Use cropped dimensions if available, otherwise original
		local width, height
		if croppedMetadata and croppedMetadata.width and croppedMetadata.height then
			width = croppedMetadata.width
			height = croppedMetadata.height
		elseif rawMetadata and rawMetadata.width and rawMetadata.height then
			width = rawMetadata.width
			height = rawMetadata.height
		else
			errorCount = errorCount + 1
			table.insert( errorMessages, "Photo " .. i .. ": No dimensions available" )
			logging:log("UpdatePhotoMetadata: No dimensions available for photo " .. i)
		end

		-- Skip if no dimensions
		if width and height then
			-- Calculate numeric aspect ratio
			local numericAspectRatio = calculateAspectRatioString( width, height )
			logging:log("UpdatePhotoMetadata: Calculated numeric aspect ratio: " .. numericAspectRatio)

			-- Get color profile data from develop settings
			-- Don't use pcall around getDevelopSettings as it interferes with yielding
			-- Since we're already in an async task context (from menu handler), getDevelopSettings can yield safely
			local baseColorProfile = nil
			local lutColorProfile = nil
			local lookAmount = nil
			local developSettings = nil

			developSettings = photo:getDevelopSettings()

			if developSettings then
				logging:log("UpdatePhotoMetadata: Got develop settings")

				-- Extract base color profile (camera calibration)
				if developSettings.CameraProfile then
					baseColorProfile = developSettings.CameraProfile
					logging:log("UpdatePhotoMetadata: Base Color Profile: " .. baseColorProfile)
				else
					logging:log("UpdatePhotoMetadata: No CameraProfile found")
				end

				-- Extract LUT color profile (Look.Name)
				if developSettings.Look and type(developSettings.Look) == "table" then
					logging:log("UpdatePhotoMetadata: Look table found")
					if developSettings.Look.Name then
						lutColorProfile = developSettings.Look.Name
						logging:log("UpdatePhotoMetadata: LUT Color Profile: " .. lutColorProfile)
					else
						logging:log("UpdatePhotoMetadata: Look.Name not found")
					end
					if developSettings.Look.Amount then
						lookAmount = tostring(developSettings.Look.Amount)
						logging:log("UpdatePhotoMetadata: Look Amount: " .. lookAmount)
					else
						logging:log("UpdatePhotoMetadata: Look.Amount not found")
					end
				else
					logging:log("UpdatePhotoMetadata: No Look table found")
				end
			else
				logging:log("UpdatePhotoMetadata: Failed to get develop settings (returned nil)")
			end

			-- Store the update
			table.insert( metadataUpdates, {
				photo = photo,
				aspectRatio = numericAspectRatio,
				baseColorProfile = baseColorProfile,
				lutColorProfile = lutColorProfile,
				lookAmount = lookAmount,
			} )
		end
	end

	-- Second pass: write all metadata in a single transaction
	local updatedCount = 0

	if #metadataUpdates > 0 then
		progressScope:setCaption( "Writing metadata..." )
		catalog:withWriteAccessDo( "Update Photo Metadata", function()
			for _, update in ipairs( metadataUpdates ) do
				update.photo:setPropertyForPlugin( _PLUGIN, 'aspectRatio', update.aspectRatio )
				if update.baseColorProfile then
					update.photo:setPropertyForPlugin( _PLUGIN, 'baseColorProfile', update.baseColorProfile )
				end
				if update.lutColorProfile then
					update.photo:setPropertyForPlugin( _PLUGIN, 'lutColorProfile', update.lutColorProfile )
				end
				if update.lookAmount then
					update.photo:setPropertyForPlugin( _PLUGIN, 'lookAmount', update.lookAmount )
				end
				updatedCount = updatedCount + 1
			end
		end )
	end

	-- Done with progress scope
	progressScope:done()

	-- Log completion
	local message = string.format( "Updated metadata for %d photos.\n%d photos had errors.", updatedCount, errorCount )
	if #errorMessages > 0 and #errorMessages <= 5 then
		message = message .. "\n\nErrors:\n" .. table.concat( errorMessages, "\n" )
	elseif #errorMessages > 5 then
		message = message .. "\n\nFirst 5 errors:\n" .. table.concat( errorMessages, "\n", 1, 5 )
	end

	logging:log("UpdatePhotoMetadata: Complete - " .. message)
end

-- Function to wipe all custom metadata from selected photos
local function wipeMetadataForSelectedPhotos()

	logging:log("WipePhotoMetadata: Starting...")

	local catalog = LrApplication.activeCatalog()
	local targetPhotos = catalog.targetPhotos

	logging:log("WipePhotoMetadata: Found " .. (targetPhotos and #targetPhotos or 0) .. " selected photos")

	if not targetPhotos or #targetPhotos == 0 then
		LrDialogs.message( "No photos selected", "Please select one or more photos to wipe metadata." )
		return
	end

	-- Create a progress scope for the native progress bar
	local progressScope = LrProgressScope {
		title = "Wiping Photo Metadata",
		cancelable = false,
	}

	local wipedCount = 0

	progressScope:setCaption( "Wiping metadata..." )
	catalog:withWriteAccessDo( "Wipe Photo Metadata", function()
		for i, photo in ipairs( targetPhotos ) do
			-- Update progress
			progressScope:setPortionComplete( i, #targetPhotos )

			-- Wipe all custom metadata fields
			photo:setPropertyForPlugin( _PLUGIN, 'aspectRatio', nil )
			photo:setPropertyForPlugin( _PLUGIN, 'baseColorProfile', nil )
			photo:setPropertyForPlugin( _PLUGIN, 'lutColorProfile', nil )
			photo:setPropertyForPlugin( _PLUGIN, 'lookAmount', nil )

			wipedCount = wipedCount + 1
		end
	end )

	-- Done with progress scope
	progressScope:done()

	logging:log("WipePhotoMetadata: Complete - Wiped metadata for " .. wipedCount .. " photos")
end

-- Export the functions for use in menu
return {
	updateMetadataForSelectedPhotos = updateMetadataForSelectedPhotos,
	wipeMetadataForSelectedPhotos = wipeMetadataForSelectedPhotos,
}
