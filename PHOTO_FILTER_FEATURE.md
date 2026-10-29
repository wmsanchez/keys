# Photo Filter Feature - Aspect Ratio & Color Profile

This feature adds custom metadata fields to your Lightroom catalog that allow you to filter photos by specific aspect ratios (like 2x3, 3x4, etc.) and color profiles in the Library module.

## What It Does

Adds three custom metadata fields to your photos:
- **Aspect Ratio**: Categorizes photos into standard ratios (1:1, 4:3, 3:2, 5:4, 16:9, 2:1, 21:9, or "other")
- **Color Profile**: Stores the active Camera Profile/Look from develop settings (e.g., "Adobe Standard", "Camera Neutral", custom profiles)
- **Orientation**: Classifies photos as landscape, portrait, or square

## How to Use

### Step 1: Update Metadata for Your Photos

1. Select the photos you want to filter (select entire catalog or specific folders/collections)
2. Go to **Library > Plug-in Extras > Update Photo Filter Metadata...**
3. The plugin will calculate and update the metadata for all selected photos
4. You'll see a progress indicator and a completion message

**Note**: The plugin intelligently detects which photos need updating. You can safely run this on your entire catalog:
- New photos will be updated
- Photos with changed crops or color profiles will be updated
- Photos that haven't changed will be skipped (fast!)

You should run this update whenever you:
- Import new photos
- Change aspect ratios (crop/uncrop)
- Apply different color profiles to photos

### Step 2: Filter in Library Module

1. In the Library module, press **\** (backslash) to show the Library Filter bar (if not visible)
2. Switch to the **Metadata** column view (third icon from left)
3. In the column headers, click to change the metadata field
4. Select **Photo Filter Metadata** from the dropdown
5. You'll now see columns for:
   - Aspect Ratio
   - Orientation
   - Color Profile
6. Click on any value in these columns to filter photos by that criteria

### Step 3: View Metadata in Metadata Panel

1. Open the Metadata panel on the right side
2. Click the Metadata Set dropdown
3. Select **Photo Filter Metadata**
4. You'll see the custom fields displayed for the selected photo

## Technical Details

### Aspect Ratio Calculation

- Uses cropped dimensions if a crop is applied, otherwise uses original dimensions
- Normalizes ratios to always be ≥ 1.0 (e.g., both 3:2 landscape and 2:3 portrait match "3:2")
- Uses a tolerance of ±0.01 (±1%) to handle pixel rounding discrepancies
- Supported ratios: 1:1, 4:3, 3:2, 5:4, 16:9, 2:1, 21:9

### Color Profile Extraction

- Reads the `CameraProfile` field from each photo's develop settings
- Supports built-in Adobe profiles, camera manufacturer profiles, and custom DCP profiles
- Works with profiles embedded in XMP sidecars

### Metadata Storage

- Custom metadata is stored in the Lightroom catalog
- Persists across Lightroom sessions
- Backed up with your catalog
- Does not modify original image files

## Troubleshooting

**Q: The metadata columns show "—" or are empty**
A: You need to run "Update Photo Filter Metadata..." on your photos first. Select the photos and run the menu command.

**Q: After cropping a photo, the aspect ratio doesn't update**
A: Run "Update Photo Filter Metadata..." again on the affected photos. The plugin will automatically detect which photos have changed and only update those. You can safely select your entire catalog—unchanged photos will be skipped quickly.

**Q: I selected 1000 photos but it only updated 5. Is this broken?**
A: No, this is working as designed! The plugin detected that 995 photos already had up-to-date metadata and skipped them. Only the 5 that had changed were updated.

**Q: Can I filter by custom aspect ratios not in the list?**
A: Currently only the standard ratios are supported. Custom ratios will be categorized as "other". You can filter by "other" to see non-standard ratios.

**Q: Does this work with virtual copies?**
A: Yes, each virtual copy can have its own metadata. Update metadata on the specific copies you want to categorize.

## Files Added

- `PhotoMetadataDefinition.lua` - Defines the custom metadata fields
- `PhotoMetadataTagset.lua` - Defines the metadata display preset
- `UpdatePhotoMetadata.lua` - Calculates and updates metadata for photos
- `UpdatePhotoMetadataMenu.lua` - Menu item handler
