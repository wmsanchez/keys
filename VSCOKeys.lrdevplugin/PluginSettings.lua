local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local JSON = require 'json'

local function getSettingsPaths()
  local appDataPath = LrPathUtils.getStandardFilePath('appData')
  if not appDataPath then return nil end
  local normalizedPath = appDataPath:gsub('\\', '/')
  local adobeDirectory = normalizedPath:match('^(.*)/[^/]+$')
  local applicationSupportDirectory = adobeDirectory and adobeDirectory:match('^(.*)/[^/]+$')
  if not applicationSupportDirectory then return nil end
  local settingsDirectory = LrPathUtils.child(applicationSupportDirectory, 'VSCOKeys')
  return settingsDirectory, LrPathUtils.child(settingsDirectory, 'plugin-settings.json')
end

local function load()
  local ok, _, settingsPath = pcall(getSettingsPaths)
  if not ok or not settingsPath then return nil end
  local exists, fileType = pcall(LrFileUtils.exists, settingsPath)
  if not exists or fileType ~= 'file' then return nil end
  local readOk, contents = pcall(LrFileUtils.readFile, settingsPath)
  if not readOk or not contents then return nil end
  local ok, settings = pcall(JSON.decode, JSON, contents)
  return ok and type(settings) == 'table' and settings or nil
end

local function save(settings)
  local ok, errorMessage = pcall(function()
    local settingsDirectory, settingsPath = getSettingsPaths()
    if not settingsPath then error('Could not resolve the VSCO Keys settings directory') end
    LrFileUtils.createAllDirectories(settingsDirectory)
    local file, openError = io.open(settingsPath, 'wb')
    if not file then error(openError) end
    local writeResult, writeError = file:write(JSON:encode(settings))
    if not writeResult then
      file:close()
      error(writeError)
    end
    local closeResult, closeError = file:close()
    if not closeResult then error(closeError) end
  end)
  return ok, ok and nil or errorMessage
end

return {
  load = load,
  save = save,
}