--[[----------------------------------------------------------------------------
ActionsTable.lua
Standalone, zero-dependency Action and Command Dispatch for VSCOKeys
Directly controls Lightroom via Lightroom SDK without external MIDI2LR modules
------------------------------------------------------------------------------]]

return function()
local LrApplication       = import 'LrApplication'
local LrApplicationView   = import 'LrApplicationView'
local LrDevelopController = import 'LrDevelopController'
local LrDialogs           = import 'LrDialogs'
local LrSelection         = import 'LrSelection'
local LrUndo              = import 'LrUndo'
local LrTasks             = import 'LrTasks'

local CU = {}

-- Ensure correct module is active
function CU.wrapFOM(F, ...)
  local args = { ... }
  return function()
    if LrApplicationView.getCurrentModuleName() ~= 'develop' then
      LrApplicationView.switchToModule('develop')
      LrTasks.yield()
    end
    return F(unpack(args))
  end
end

function CU.execFOM(F, ...)
  if LrApplicationView.getCurrentModuleName() ~= 'develop' then
    LrApplicationView.switchToModule('develop')
    LrTasks.yield()
  end
  return F(...)
end

local wfep_action = {
  QuickDevWBAuto                  = function(T) T:quickDevelopSetWhiteBalance("Auto") end,
  QuickDevWBCloudy                = function(T) T:quickDevelopSetWhiteBalance("Cloudy") end,
  QuickDevWBDaylight              = function(T) T:quickDevelopSetWhiteBalance("Daylight") end,
  QuickDevWBFlash                 = function(T) T:quickDevelopSetWhiteBalance("Flash") end,
  QuickDevWBFluorescent           = function(T) T:quickDevelopSetWhiteBalance("Fluorescent") end,
  QuickDevWBShade                 = function(T) T:quickDevelopSetWhiteBalance("Shade") end,
  QuickDevWBTungsten              = function(T) T:quickDevelopSetWhiteBalance("Tungsten") end,
  SetTreatmentBW                  = function(T) T:quickDevelopSetTreatment("grayscale") end,
  SetTreatmentColor               = function(T) T:quickDevelopSetTreatment("color") end,
  addOrRemoveFromTargetCollection = function(T) T:addOrRemoveFromTargetCollection() end,
  openExportDialog                = function(T) T:openExportDialog() end,
  openExportWithPreviousDialog    = function(T) T:openExportWithPreviousDialog() end,
  rotateLeft                      = function(T) T:rotateLeft() end,
  rotateRight                     = function(T) T:rotateRight() end,
}

function CU.wrapForEachPhoto(actionName)
  local fn = wfep_action[actionName]
  return function()
    local cat = LrApplication.activeCatalog()
    local target = cat and cat:getTargetPhoto()
    if target and fn then
      fn(target)
    end
  end
end

function CU.QuickCropAspect(aspect)
  local cat = LrApplication.activeCatalog()
  local target = cat and cat:getTargetPhoto()
  if target then
    target:quickDevelopCropAspect(aspect)
  end
end

function CU.fChangeModule(modName)
  return function()
    if LrApplicationView.getCurrentModuleName() ~= modName then
      LrApplicationView.switchToModule(modName)
    end
  end
end

function CU.fChangePanel(panelName)
  return function()
    if LrApplicationView.getCurrentModuleName() ~= 'develop' then
      LrApplicationView.switchToModule('develop')
      LrTasks.yield()
    end
    LrDevelopController.revealPanel(panelName)
  end
end

function CU.fToggle01(param)
  return function()
    if LrApplicationView.getCurrentModuleName() ~= 'develop' then
      LrApplicationView.switchToModule('develop')
      LrTasks.yield()
    end
    local val = LrDevelopController.getValue(param)
    local newval = (val == 1) and 0 or 1
    LrDevelopController.setValue(param, newval)
  end
end

function CU.fToggle01Async(param)
  return function()
    LrTasks.startAsyncTask(function()
      if LrApplicationView.getCurrentModuleName() ~= 'develop' then
        LrApplicationView.switchToModule('develop')
        LrTasks.yield()
      end
      local val = LrDevelopController.getValue(param)
      local newval = (val == 1) and 0 or 1
      LrDevelopController.setValue(param, newval)
    end)
  end
end

function CU.fToggleTFasync(param)
  return function()
    LrTasks.startAsyncTask(function()
      if LrApplicationView.getCurrentModuleName() ~= 'develop' then
        LrApplicationView.switchToModule('develop')
        LrTasks.yield()
      end
      local val = LrDevelopController.getValue(param)
      local newval = not val
      LrDevelopController.setValue(param, newval)
    end)
  end
end

function CU.fToggle1ModN(param, n)
  return function()
    if LrApplicationView.getCurrentModuleName() ~= 'develop' then
      LrApplicationView.switchToModule('develop')
      LrTasks.yield()
    end
    local val = tonumber(LrDevelopController.getValue(param)) or 1
    local newval = (val % n) + 1
    LrDevelopController.setValue(param, newval)
  end
end

function CU.fToggleTool(toolName)
  return function()
    if LrApplicationView.getCurrentModuleName() ~= 'develop' then
      LrApplicationView.switchToModule('develop')
      LrTasks.yield()
    end
    local curTool = LrDevelopController.getSelectedTool()
    if curTool == toolName then
      LrDevelopController.selectTool('loupe')
    else
      LrDevelopController.selectTool(toolName)
    end
  end
end

function CU.fToggleTool1(toolName)
  return function()
    if LrApplicationView.getCurrentModuleName() ~= 'develop' then
      LrApplicationView.switchToModule('develop')
      LrTasks.yield()
    end
    local curTool = LrDevelopController.getSelectedTool()
    if curTool == toolName then
      LrDevelopController.selectTool('loupe')
    else
      LrDevelopController.selectTool(toolName)
    end
  end
end

function CU.quickDevAdjust(param, step)
  return function()
    local cat = LrApplication.activeCatalog()
    local target = cat and cat:getTargetPhoto()
    if target then
      target:quickDevelopAdjustImage(param, step)
    end
  end
end

function CU.quickDevAdjustWB(param, step)
  return function()
    local cat = LrApplication.activeCatalog()
    local target = cat and cat:getTargetPhoto()
    if target then
      target:quickDevelopAdjustWhiteBalance(param, step)
    end
  end
end

function CU.UpdatePointCurve(curveSettings)
  return function()
    if LrApplicationView.getCurrentModuleName() ~= 'develop' then
      LrApplicationView.switchToModule('develop')
      LrTasks.yield()
    end
    for k, v in pairs(curveSettings) do
      LrDevelopController.setValue(k, v)
    end
  end
end

local cg_pasteboard = {}
function CU.cg_hsl_copy()
  if LrApplicationView.getCurrentModuleName() ~= 'develop' then
    LrApplicationView.switchToModule('develop')
    LrTasks.yield()
  end
  cg_pasteboard = {
    ColorGradeMidtoneHue = LrDevelopController.getValue('ColorGradeMidtoneHue'),
    ColorGradeMidtoneSat = LrDevelopController.getValue('ColorGradeMidtoneSat'),
    ColorGradeMidtoneLum = LrDevelopController.getValue('ColorGradeMidtoneLum'),
    SplitToningShadowHue = LrDevelopController.getValue('SplitToningShadowHue'),
    SplitToningShadowSaturation = LrDevelopController.getValue('SplitToningShadowSaturation'),
    ColorGradeShadowLum = LrDevelopController.getValue('ColorGradeShadowLum'),
    SplitToningHighlightHue = LrDevelopController.getValue('SplitToningHighlightHue'),
    SplitToningHighlightSaturation = LrDevelopController.getValue('SplitToningHighlightSaturation'),
    ColorGradeHighlightLum = LrDevelopController.getValue('ColorGradeHighlightLum'),
    ColorGradeGlobalHue = LrDevelopController.getValue('ColorGradeGlobalHue'),
    ColorGradeGlobalSat = LrDevelopController.getValue('ColorGradeGlobalSat'),
    ColorGradeGlobalLum = LrDevelopController.getValue('ColorGradeGlobalLum'),
  }
end

function CU.cg_hsl_paste()
  if LrApplicationView.getCurrentModuleName() ~= 'develop' then
    LrApplicationView.switchToModule('develop')
    LrTasks.yield()
  end
  for k, v in pairs(cg_pasteboard) do
    if v ~= nil then
      LrDevelopController.setValue(k, v)
    end
  end
end

function CU.cg_reset_3way()
  if LrApplicationView.getCurrentModuleName() ~= 'develop' then
    LrApplicationView.switchToModule('develop')
    LrTasks.yield()
  end
  local params = {
    'ColorGradeMidtoneHue', 'ColorGradeMidtoneSat', 'ColorGradeMidtoneLum',
    'SplitToningShadowHue', 'SplitToningShadowSaturation', 'ColorGradeShadowLum',
    'SplitToningHighlightHue', 'SplitToningHighlightSaturation', 'ColorGradeHighlightLum'
  }
  for _, p in ipairs(params) do
    LrDevelopController.resetToDefault(p)
  end
end

function CU.cg_reset_all()
  if LrApplicationView.getCurrentModuleName() ~= 'develop' then
    LrApplicationView.switchToModule('develop')
    LrTasks.yield()
  end
  local params = {
    'ColorGradeMidtoneHue', 'ColorGradeMidtoneSat', 'ColorGradeMidtoneLum',
    'SplitToningShadowHue', 'SplitToningShadowSaturation', 'ColorGradeShadowLum',
    'SplitToningHighlightHue', 'SplitToningHighlightSaturation', 'ColorGradeHighlightLum',
    'ColorGradeGlobalHue', 'ColorGradeGlobalSat', 'ColorGradeGlobalLum', 'ColorGradeBlending'
  }
  for _, p in ipairs(params) do
    LrDevelopController.resetToDefault(p)
  end
end

function CU.cg_reset_current()
  CU.cg_reset_all()
end

function CU.ResetAllHueAdjustment()
  if LrApplicationView.getCurrentModuleName() ~= 'develop' then
    LrApplicationView.switchToModule('develop')
    LrTasks.yield()
  end
  local colors = {'Red', 'Orange', 'Yellow', 'Green', 'Aqua', 'Blue', 'Purple', 'Magenta'}
  for _, c in ipairs(colors) do
    LrDevelopController.resetToDefault('HueAdjustment' .. c)
  end
end

function CU.ResetAllSaturationAdjustment()
  if LrApplicationView.getCurrentModuleName() ~= 'develop' then
    LrApplicationView.switchToModule('develop')
    LrTasks.yield()
  end
  local colors = {'Red', 'Orange', 'Yellow', 'Green', 'Aqua', 'Blue', 'Purple', 'Magenta'}
  for _, c in ipairs(colors) do
    LrDevelopController.resetToDefault('SaturationAdjustment' .. c)
  end
end

function CU.ResetAllLuminanceAdjustment()
  if LrApplicationView.getCurrentModuleName() ~= 'develop' then
    LrApplicationView.switchToModule('develop')
    LrTasks.yield()
  end
  local colors = {'Red', 'Orange', 'Yellow', 'Green', 'Aqua', 'Blue', 'Purple', 'Magenta'}
  for _, c in ipairs(colors) do
    LrDevelopController.resetToDefault('LuminanceAdjustment' .. c)
  end
end

function CU.ResetAllGrayMixer()
  if LrApplicationView.getCurrentModuleName() ~= 'develop' then
    LrApplicationView.switchToModule('develop')
    LrTasks.yield()
  end
  local colors = {'Red', 'Orange', 'Yellow', 'Green', 'Aqua', 'Blue', 'Purple', 'Magenta'}
  for _, c in ipairs(colors) do
    LrDevelopController.resetToDefault('GrayMixer' .. c)
  end
end

local ACTIONS = {
  AddOrRemoveFromTargetColl = CU.wrapForEachPhoto('addOrRemoveFromTargetCollection'),
  AutoLateralCA = CU.fToggle01('AutoLateralCA'),
  AutoTone = function() LrDevelopController.setAutoTone(); LrDevelopController.revealPanel('adjustPanel'); end,
  BlurDepthShow = CU.wrapFOM(LrDevelopController.toggleLensBlurDepthVisualization),
  BokehAnamorphic = CU.wrapFOM(LrDevelopController.setLensBlurBokeh, 'Anamorphic'),
  BokehBlade = CU.wrapFOM(LrDevelopController.setLensBlurBokeh, 'Blade'),
  BokehCircle = CU.wrapFOM(LrDevelopController.setLensBlurBokeh, 'Circle'),
  BokehRing = CU.wrapFOM(LrDevelopController.setLensBlurBokeh, 'Ring'),
  BokehSoapBubble = CU.wrapFOM(LrDevelopController.setLensBlurBokeh, 'SoapBubble'),
  ColorGrade3Way = CU.wrapFOM(LrDevelopController.setActiveColorGradingView,'3-way'),
  ColorGradeCopy = CU.cg_hsl_copy,
  ColorGradeGlobal = CU.wrapFOM(LrDevelopController.setActiveColorGradingView,'global'),
  ColorGradeHighlight = CU.wrapFOM(LrDevelopController.setActiveColorGradingView,'highlight'),
  ColorGradeMidtone = CU.wrapFOM(LrDevelopController.setActiveColorGradingView,'midtone'),
  ColorGradePaste = CU.cg_hsl_paste,
  ColorGradeReset3way = CU.cg_reset_3way,
  ColorGradeResetAll = CU.cg_reset_all,
  ColorGradeResetCurrent = CU.cg_reset_current,
  ColorGradeShadow = CU.wrapFOM(LrDevelopController.setActiveColorGradingView,'shadow'),
  ColorLabelNone = function() LrSelection.setColorLabel("none") end,
  ConvertToGrayscale = CU.fToggleTFasync('ConvertToGrayscale'),
  CropConstrainToWarp = CU.fToggle01('CropConstrainToWarp'),
  CropOverlay = CU.fToggleTool('crop'),
  CycleLoupeViewInfo = LrApplicationView.cycleLoupeViewInfo,
  DecreaseRating = LrSelection.decreaseRating,
  DecrementLastDevelopParameter = function() CU.execFOM(LrDevelopController.decrement,LastParam) end,
  EditPhotoshop = LrDevelopController.editInPhotoshop,
  EnableCalibration = CU.fToggleTFasync('EnableCalibration'),
  EnableColorAdjustments = CU.fToggleTFasync('EnableColorAdjustments'),
  EnableColorGrading = CU.fToggleTFasync('EnableSplitToning'),
  EnableDetail = CU.fToggleTFasync('EnableDetail'),
  EnableEffects = CU.fToggleTFasync('EnableEffects'),
  EnableGrayscaleMix = CU.fToggleTFasync('EnableGrayscaleMix'),
  EnableLensCorrections = CU.fToggleTFasync('EnableLensCorrections'),
  EnableRedEye = CU.fToggleTFasync('EnableRedEye'),
  EnableRetouch = CU.fToggleTFasync('EnableRetouch'),
  EnableToneCurve = CU.fToggleTFasync('EnableToneCurve'),
  EnableTransform = CU.fToggleTFasync('EnableTransform'),
  GridViewStyle = LrApplicationView.gridViewStyle,
  HDREditMode = CU.fToggle01('HDREditMode'),
  HoldAltOpt = CU.HoldAltOptToggle,
  IncreaseRating = LrSelection.increaseRating,
  IncrementLastDevelopParameter = function() CU.execFOM(LrDevelopController.increment,LastParam) end,
  LensBlurActive = function() LrDevelopController.setValue('LensBlurActive', not LrDevelopController.getValue('LensBlurActive')) end,
  LensProfileEnable = CU.fToggle01Async('LensProfileEnable'),
  Loupe = CU.fToggleTool('loupe'),
  Mask = CU.fToggleTool1('masking'),
  MaskAddBack = CU.wrapFOM(LrDevelopController.addToCurrentMask,'aiSelection','background'),
  MaskAddBrush = CU.wrapFOM(LrDevelopController.addToCurrentMask,'brush'),
  MaskAddColor = CU.wrapFOM(LrDevelopController.addToCurrentMask,'rangeMask','color'),
  MaskAddDepth = CU.wrapFOM(LrDevelopController.addToCurrentMask,'rangeMask','depth'),
  MaskAddGrad = CU.wrapFOM(LrDevelopController.addToCurrentMask,'gradient'),
  MaskAddLand = CU.wrapFOM(LrDevelopController.addToCurrentMask,'aiSelection','landscape'),
  MaskAddLum = CU.wrapFOM(LrDevelopController.addToCurrentMask,'rangeMask','luminance'),
  MaskAddObj = CU.wrapFOM(LrDevelopController.addToCurrentMask,'aiSelection','objects'),
  MaskAddPeople = CU.wrapFOM(LrDevelopController.addToCurrentMask,'aiSelection','people'),
  MaskAddRad = CU.wrapFOM(LrDevelopController.addToCurrentMask,'radialGradient'),
  MaskAddSky = CU.wrapFOM(LrDevelopController.addToCurrentMask,'aiSelection','sky'),
  MaskAddSubject = CU.wrapFOM(LrDevelopController.addToCurrentMask,'aiSelection','subject'),
  MaskEnable = CU.fToggleTFasync('EnableMaskGroupBasedCorrections'),
  MaskIntBack = CU.wrapFOM(LrDevelopController.intersectWithCurrentMask,'aiSelection','background'),
  MaskIntBrush = CU.wrapFOM(LrDevelopController.intersectWithCurrentMask,'brush'),
  MaskIntColor = CU.wrapFOM(LrDevelopController.intersectWithCurrentMask,'rangeMask','color'),
  MaskIntDepth = CU.wrapFOM(LrDevelopController.intersectWithCurrentMask,'rangeMask','depth'),
  MaskIntGrad = CU.wrapFOM(LrDevelopController.intersectWithCurrentMask,'gradient'),
  MaskIntLand = CU.wrapFOM(LrDevelopController.intersectWithCurrentMask,'aiSelection','landscape'),
  MaskIntLum = CU.wrapFOM(LrDevelopController.intersectWithCurrentMask,'rangeMask','luminance'),
  MaskIntObj = CU.wrapFOM(LrDevelopController.intersectWithCurrentMask,'aiSelection','objects'),
  MaskIntPeople = CU.wrapFOM(LrDevelopController.intersectWithCurrentMask,'aiSelection','people'),
  MaskIntRad = CU.wrapFOM(LrDevelopController.intersectWithCurrentMask,'radialGradient'),
  MaskIntSky = CU.wrapFOM(LrDevelopController.intersectWithCurrentMask,'aiSelection','sky'),
  MaskIntSubject = CU.wrapFOM(LrDevelopController.intersectWithCurrentMask,'aiSelection','subject'),
  MaskNewBack = CU.wrapFOM(LrDevelopController.createNewMask,'aiSelection','background'),
  MaskNewBrush = CU.wrapFOM(LrDevelopController.createNewMask,'brush'),
  MaskNewColor = CU.wrapFOM(LrDevelopController.createNewMask,'rangeMask','color'),
  MaskNewDepth = CU.wrapFOM(LrDevelopController.createNewMask,'rangeMask','depth'),
  MaskNewGrad = CU.wrapFOM(LrDevelopController.createNewMask,'gradient'),
  MaskNewLand = CU.wrapFOM(LrDevelopController.createNewMask,'aiSelection','landscape'),
  MaskNewLum = CU.wrapFOM(LrDevelopController.createNewMask,'rangeMask','luminance'),
  MaskNewObj = CU.wrapFOM(LrDevelopController.createNewMask,'aiSelection','objects'),
  MaskNewPeople = CU.wrapFOM(LrDevelopController.createNewMask,'aiSelection','people'),
  MaskNewRad = CU.wrapFOM(LrDevelopController.createNewMask,'radialGradient'),
  MaskNewSky = CU.wrapFOM(LrDevelopController.createNewMask,'aiSelection','sky'),
  MaskNewSubject = CU.wrapFOM(LrDevelopController.createNewMask,'aiSelection','subject'),
  MaskReset = CU.wrapFOM(LrDevelopController.resetMasking),
  MaskSubBack = CU.wrapFOM(LrDevelopController.subtractFromCurrentMask,'aiSelection','background'),
  MaskSubBrush = CU.wrapFOM(LrDevelopController.subtractFromCurrentMask,'brush'),
  MaskSubColor = CU.wrapFOM(LrDevelopController.subtractFromCurrentMask,'rangeMask','color'),
  MaskSubDepth = CU.wrapFOM(LrDevelopController.subtractFromCurrentMask,'rangeMask','depth'),
  MaskSubGrad = CU.wrapFOM(LrDevelopController.subtractFromCurrentMask,'gradient'),
  MaskSubLum = CU.wrapFOM(LrDevelopController.subtractFromCurrentMask,'rangeMask','luminance'),
  MaskSubObj = CU.wrapFOM(LrDevelopController.subtractFromCurrentMask,'aiSelection','objects'),
  MaskSubPeople = CU.wrapFOM(LrDevelopController.subtractFromCurrentMask,'aiSelection','people'),
  MaskSubRad = CU.wrapFOM(LrDevelopController.subtractFromCurrentMask,'radialGradient'),
  MaskSubSky = CU.wrapFOM(LrDevelopController.subtractFromCurrentMask,'aiSelection','sky'),
  MaskSubSubject = CU.wrapFOM(LrDevelopController.subtractFromCurrentMask,'aiSelection','subject'),
  Next = LrSelection.nextPhoto,
  NextScreenMode = LrApplicationView.nextScreenMode,
  PV1 = CU.wrapFOM(LrDevelopController.setProcessVersion, 'Version 1'),
  PV2 = CU.wrapFOM(LrDevelopController.setProcessVersion, 'Version 2'),
  PV3 = CU.wrapFOM(LrDevelopController.setProcessVersion, 'Version 3'),
  PV4 = CU.wrapFOM(LrDevelopController.setProcessVersion, 'Version 4'),
  PV5 = CU.wrapFOM(LrDevelopController.setProcessVersion, 'Version 5'),
  Pause = function() LrTasks.sleep( 0.02 ) end,
  Pick = LrSelection.flagAsPick,
  PointCurveBlacksDown = CU.PointCurveUpDown and CU.PointCurveUpDown(true, false),
  PointCurveBlacksUp = CU.PointCurveUpDown and CU.PointCurveUpDown(true, true),
  PointCurveHighlightsDown = CU.PointCurveUpDown and CU.PointCurveUpDown(false, false),
  PointCurveHighlightsUp = CU.PointCurveUpDown and CU.PointCurveUpDown(false, true),
  PointCurveLinear = CU.UpdatePointCurve({ToneCurveName="Linear",ToneCurveName2012="Linear",ToneCurvePV2012={0,0,255,255,}}),
  PointCurveMediumContrast = CU.UpdatePointCurve({ToneCurveName="Medium Contrast",ToneCurveName2012="Medium Contrast",ToneCurvePV2012={0,0,32,22,64,56,128,128,192,196,255,255,}}),
  PointCurveStrongContrast = CU.UpdatePointCurve({ToneCurveName="Strong Contrast",ToneCurveName2012="Strong Contrast",ToneCurvePV2012={0,0,32,16,64,50,128,128,192,202,255,255,}}),
  PostCropVignetteStyle = CU.fToggle1ModN('PostCropVignetteStyle', 3),
  PostCropVignetteStyleColorPriority = CU.wrapFOM(LrDevelopController.setValue,'PostCropVignetteStyle',2),
  PostCropVignetteStyleHighlightPriority = CU.wrapFOM(LrDevelopController.setValue,'PostCropVignetteStyle',1),
  PostCropVignetteStylePaintOverlay = CU.wrapFOM(LrDevelopController.setValue,'PostCropVignetteStyle',3),
  Prev = LrSelection.previousPhoto,
  QuickDevBlacksLarge = CU.quickDevAdjust('Blacks',20,'QuickDevBlacksLarge'),
  QuickDevBlacksLargeDec = CU.quickDevAdjust('Blacks',-20,'QuickDevBlacksLargeDec'),
  QuickDevBlacksSmall = CU.quickDevAdjust('Blacks',5,'QuickDevBlacksSmall'),
  QuickDevBlacksSmallDec = CU.quickDevAdjust('Blacks',-5,'QuickDevBlacksSmallDec'),
  QuickDevClarityLarge = CU.quickDevAdjust('Clarity',20,'QuickDevClarityLarge'),
  QuickDevClarityLargeDec = CU.quickDevAdjust('Clarity',-20,'QuickDevClarityLargeDec'),
  QuickDevClaritySmall = CU.quickDevAdjust('Clarity',5,'QuickDevClaritySmall'),
  QuickDevClaritySmallDec = CU.quickDevAdjust('Clarity',-5,'QuickDevClaritySmallDec'),
  QuickDevContrastLarge = CU.quickDevAdjust('Contrast',20,'QuickDevContrastLarge'),
  QuickDevContrastLargeDec = CU.quickDevAdjust('Contrast',-20,'QuickDevContrastLargeDec'),
  QuickDevContrastSmall = CU.quickDevAdjust('Contrast',5,'QuickDevContrastSmall'),
  QuickDevContrastSmallDec = CU.quickDevAdjust('Contrast',-5,'QuickDevContrastSmallDec'),
  QuickDevCropAspect1x1 = function() CU.QuickCropAspect({w=1,h=1}) end,
  QuickDevCropAspect2x3 = function() CU.QuickCropAspect({w=2,h=3}) end,
  QuickDevCropAspect3x4 = function() CU.QuickCropAspect({w=3,h=4}) end,
  QuickDevCropAspect4x5 = function() CU.QuickCropAspect({w=4,h=5}) end,
  QuickDevCropAspect5x7 = function() CU.QuickCropAspect({w=5,h=7}) end,
  QuickDevCropAspect85x11 = function() CU.QuickCropAspect({w=8.5,h=11}) end,
  QuickDevCropAspect9x16 = function() CU.QuickCropAspect({w=9,h=16}) end,
  QuickDevCropAspectAsShot = function() CU.QuickCropAspect('asshot') end,
  QuickDevCropAspectOriginal = function() CU.QuickCropAspect('original') end,
  QuickDevExpLarge = CU.quickDevAdjust('Exposure',50,'QuickDevExpLarge'),
  QuickDevExpLargeDec = CU.quickDevAdjust('Exposure',-50,'QuickDevExpLargeDec'),
  QuickDevExpSmHalf = CU.quickDevAdjust('Exposure',8.25,'QuickDevExpSmHalf'),
  QuickDevExpSmHalfDec = CU.quickDevAdjust('Exposure',-8.25,'QuickDevExpSmHalfDec'),
  QuickDevExpSmall = CU.quickDevAdjust('Exposure',16.5,'QuickDevExpSmall'),
  QuickDevExpSmallDec = CU.quickDevAdjust('Exposure',-16.5,'QuickDevExpSmallDec'),
  QuickDevHighlightsLarge = CU.quickDevAdjust('Highlights',20,'QuickDevHighlightsLarge'),
  QuickDevHighlightsLargeDec = CU.quickDevAdjust('Highlights',-20,'QuickDevHighlightsLargeDec'),
  QuickDevHighlightsSmall = CU.quickDevAdjust('Highlights',5,'QuickDevHighlightsSmall'),
  QuickDevHighlightsSmallDec = CU.quickDevAdjust('Highlights',-5,'QuickDevHighlightsSmallDec'),
  QuickDevSatLarge = CU.quickDevAdjust('Saturation',20,'QuickDevSatLarge'),
  QuickDevSatLargeDec = CU.quickDevAdjust('Saturation',-20,'QuickDevSatLargeDec'),
  QuickDevSatSmall = CU.quickDevAdjust('Saturation',5,'QuickDevSatSmall'),
  QuickDevSatSmallDec = CU.quickDevAdjust('Saturation',-5,'QuickDevSatSmallDec'),
  QuickDevShadowsLarge = CU.quickDevAdjust('Shadows',20,'QuickDevShadowsLarge'),
  QuickDevShadowsLargeDec = CU.quickDevAdjust('Shadows',-20,'QuickDevShadowsLargeDec'),
  QuickDevShadowsSmall = CU.quickDevAdjust('Shadows',5,'QuickDevShadowsSmall'),
  QuickDevShadowsSmallDec = CU.quickDevAdjust('Shadows',-5,'QuickDevShadowsSmallDec'),
  QuickDevTempLarge = CU.quickDevAdjustWB('Temperature',20,'QuickDevTempLarge'),
  QuickDevTempLargeDec = CU.quickDevAdjustWB('Temperature',-20,'QuickDevTempLargeDec'),
  QuickDevTempSmalDec = CU.quickDevAdjustWB('Temperature',-5,'QuickDevTempSmalDec'),
  QuickDevTempSmall = CU.quickDevAdjustWB('Temperature',5,'QuickDevTempSmall'),
  QuickDevTintLarge = CU.quickDevAdjustWB('Tint',20,'QuickDevTintLarge'),
  QuickDevTintLargeDec = CU.quickDevAdjustWB('Tint',-20,'QuickDevTintLargeDec'),
  QuickDevTintSmall = CU.quickDevAdjustWB('Tint',5,'QuickDevTintSmall'),
  QuickDevTintSmallDec = CU.quickDevAdjustWB('Tint',-5,'QuickDevTintSmallDec'),
  QuickDevVibranceLarge = CU.quickDevAdjust('Vibrance',20,'QuickDevVibranceLarge'),
  QuickDevVibranceLargeDec = CU.quickDevAdjust('Vibrance',-20,'QuickDevVibranceLargeDec'),
  QuickDevVibranceSmall = CU.quickDevAdjust('Vibrance',5,'QuickDevVibranceSmall'),
  QuickDevVibranceSmallDec = CU.quickDevAdjust('Vibrance',-5,'QuickDevVibranceSmallDec'),
  QuickDevWBAuto = CU.wrapForEachPhoto('QuickDevWBAuto'),
  QuickDevWBCloudy = CU.wrapForEachPhoto('QuickDevWBCloudy'),
  QuickDevWBDaylight = CU.wrapForEachPhoto('QuickDevWBDaylight'),
  QuickDevWBFlash = CU.wrapForEachPhoto('QuickDevWBFlash'),
  QuickDevWBFluorescent = CU.wrapForEachPhoto('QuickDevWBFluorescent'),
  QuickDevWBShade = CU.wrapForEachPhoto('QuickDevWBShade'),
  QuickDevWBTungsten = CU.wrapForEachPhoto('QuickDevWBTungsten'),
  QuickDevWhitesLarge = CU.quickDevAdjust('Whites',20,'QuickDevWhitesLarge'),
  QuickDevWhitesLargeDec = CU.quickDevAdjust('Whites',-20,'QuickDevWhitesLargeDec'),
  QuickDevWhitesSmall = CU.quickDevAdjust('Whites',5,'QuickDevWhitesSmall'),
  QuickDevWhitesSmallDec = CU.quickDevAdjust('Whites',-5,'QuickDevWhitesSmallDec'),
  RedEye = CU.fToggleTool('redeye'),
  Redo = LrUndo.redo,
  Reject = LrSelection.flagAsReject,
  RemoveFlag = LrSelection.removeFlag,
  ResetAll = CU.wrapFOM(LrDevelopController.resetAllDevelopAdjustments),
  ResetAllGrayMixer = CU.ResetAllGrayMixer,
  ResetAllHueAdjustment = CU.ResetAllHueAdjustment,
  ResetAllLuminanceAdjustment = CU.ResetAllLuminanceAdjustment,
  ResetAllSaturationAdjustment = CU.ResetAllSaturationAdjustment,
  ResetCrop = CU.wrapFOM(LrDevelopController.resetCrop),
  ResetHealing = CU.wrapFOM(LrDevelopController.resetHealing),
  ResetLast = function() CU.execFOM(LrDevelopController.resetToDefault,LastParam) end,
  ResetRedeye = CU.wrapFOM(LrDevelopController.resetRedeye),
  ResetTransforms = CU.wrapFOM(LrDevelopController.resetTransforms),
  RevealPanelAdjust = CU.fChangePanel('adjustPanel'),
  RevealPanelCalibrate = CU.fChangePanel('calibratePanel'),
  RevealPanelColorGrading = CU.fChangePanel('colorGradingPanel'),
  RevealPanelDetail = CU.fChangePanel('detailPanel'),
  RevealPanelEffects = CU.fChangePanel('effectsPanel'),
  RevealPanelLens = CU.fChangePanel('lensCorrectionsPanel'),
  RevealPanelLensBlur = CU.fChangePanel('lensBlurPanel'),
  RevealPanelMixer = CU.fChangePanel('mixerPanel'),
  RevealPanelSplit = CU.fChangePanel('splitToningPanel'),
  RevealPanelTone = CU.fChangePanel('tonePanel'),
  RevealPanelTransform = CU.fChangePanel('transformPanel'),
  RotateLeft = CU.wrapForEachPhoto('rotateLeft'),
  RotateRight = CU.wrapForEachPhoto('rotateRight'),
  Select1Left = function() LrSelection.extendSelection('left',1) end,
  Select1Right = function() LrSelection.extendSelection('right',1) end,
  SetRating0 = function() LrSelection.setRating(0) end,
  SetRating1 = function() LrSelection.setRating(1) end,
  SetRating2 = function() LrSelection.setRating(2) end,
  SetRating3 = function() LrSelection.setRating(3) end,
  SetRating4 = function() LrSelection.setRating(4) end,
  SetRating5 = function() LrSelection.setRating(5) end,
  SetTreatmentBW = CU.wrapForEachPhoto('SetTreatmentBW'),
  SetTreatmentColor = CU.wrapForEachPhoto('SetTreatmentColor'),
  ShoFullHidePanels = LrApplicationView.fullscreenHidePanels,
  ShoFullPreview = LrApplicationView.fullscreenPreview,
  ShoScndVwcompare = function() LrApplicationView.showSecondaryView('compare') end,
  ShoScndVwgrid = function() LrApplicationView.showSecondaryView('grid') end,
  ShoScndVwlive_loupe = function() LrApplicationView.showSecondaryView('live_loupe') end,
  ShoScndVwlocked_loupe = function() LrApplicationView.showSecondaryView('locked_loupe') end,
  ShoScndVwloupe = function() LrApplicationView.showSecondaryView('loupe') end,
  ShoScndVwslideshow = function() LrApplicationView.showSecondaryView('slideshow') end,
  ShoScndVwsurvey = function() LrApplicationView.showSecondaryView('survey') end,
  ShoVwRefHoriz = function() LrApplicationView.showView('develop_reference_horiz') end,
  ShoVwRefVert = function() LrApplicationView.showView('develop_reference_vert') end,
  ShoVwcompare = function() LrApplicationView.showView('compare') end,
  ShoVwdevelop_before = function() LrApplicationView.showView('develop_before') end,
  ShoVwdevelop_before_after_horiz = function() LrApplicationView.showView('develop_before_after_horiz') end,
  ShoVwdevelop_before_after_vert = function() LrApplicationView.showView('develop_before_after_vert') end,
  ShoVwdevelop_loupe = function() LrApplicationView.showView('develop_loupe') end,
  ShoVwgrid = function() LrApplicationView.showView('grid') end,
  ShoVwloupe = function() LrApplicationView.showView('loupe') end,
  ShoVwpeople = function() LrApplicationView.showView('people') end,
  ShoVwsurvey = function() LrApplicationView.showView('survey') end,
  ShowClipping = CU.wrapFOM(LrDevelopController.showClipping),
  ShowSlideShow = CU.ToggleSlideshow and CU.ToggleSlideshow(),
  SpotRemoval = CU.fToggleTool1('dust'),
  SwToMbook = CU.fChangeModule('book'),
  SwToMdevelop = CU.fChangeModule('develop'),
  SwToMlibrary = CU.fChangeModule('library'),
  SwToMmap = CU.fChangeModule('map'),
  SwToMprint = CU.fChangeModule('print'),
  SwToMslideshow = CU.fChangeModule('slideshow'),
  SwToMweb = CU.fChangeModule('web'),
  ToggleBlue = LrSelection.toggleBlueLabel,
  ToggleGreen = LrSelection.toggleGreenLabel,
  ToggleLoupe = LrApplicationView.toggleLoupe,
  ToggleOverlay = LrDevelopController.toggleOverlay,
  TogglePurple = LrSelection.togglePurpleLabel,
  ToggleRed = LrSelection.toggleRedLabel,
  ToggleScreenTwo = LrApplicationView.toggleSecondaryDisplay,
  ToggleYellow = LrSelection.toggleYellowLabel,
  ToggleZoomOffOn = LrApplicationView.toggleZoom,
  Undo = LrUndo.undo,
  UpdateAISettings = CU.UpdateAI,
  UpdateAISettingsAll = CU.UpdateAIAll,
  UprightAuto = CU.wrapFOM(LrDevelopController.setValue,'PerspectiveUpright',1),
  UprightFull = CU.wrapFOM(LrDevelopController.setValue,'PerspectiveUpright',2),
  UprightGuided = CU.wrapFOM(LrDevelopController.setValue,'PerspectiveUpright',5),
  UprightLevel = CU.wrapFOM(LrDevelopController.setValue,'PerspectiveUpright',3),
  UprightOff = CU.wrapFOM(LrDevelopController.setValue,'PerspectiveUpright',0),
  UprightVertical = CU.wrapFOM(LrDevelopController.setValue,'PerspectiveUpright',4),
  VirtualCopy = function() LrApplication.activeCatalog():createVirtualCopies() end,
  WhiteBalanceAs_Shot = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','As Shot'),
  WhiteBalanceAuto = LrDevelopController.setAutoWhiteBalance,
  WhiteBalanceCloudy = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Cloudy'),
  WhiteBalanceDaylight = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Daylight'),
  WhiteBalanceFlash = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Flash'),
  WhiteBalanceFluorescent = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Fluorescent'),
  WhiteBalanceShade = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Shade'),
  WhiteBalanceTungsten = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Tungsten'),
  ZoomInLargeStep = LrApplicationView.zoomIn,
  ZoomInSmallStep = LrApplicationView.zoomInSome,
  ZoomOutLargeStep = LrApplicationView.zoomOut,
  ZoomOutSmallStep = LrApplicationView.zoomOutSome,
  ZoomTo100 = LrApplicationView.zoomToOneToOne,
  openExportDialog = CU.wrapForEachPhoto('openExportDialog'),
  openExportWithPreviousDialog = CU.wrapForEachPhoto('openExportWithPreviousDialog')  ,
}

return ACTIONS
end
