local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrHttp = import 'LrHttp'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrFileUtils = import 'LrFileUtils'
local JSON = require 'json'
local PluginSettings = require 'PluginSettings'
local prefs = LrPrefs.prefsForPlugin()
local settingsEndpoint = 'http://127.0.0.1:49657/Settings/'

local catalogPath = _PLUGIN.path .. '/CommandCategories.json'
local catalogContents = LrFileUtils.readFile(catalogPath)
local catalog = catalogContents and JSON:decode(catalogContents) or {}
local commands = {}

for _, category in ipairs(catalog) do
  for _, command in ipairs(category.items or {}) do
    table.insert(commands, {
      id = command.id,
      name = command.name or command.id,
      category = category.category or 'Other',
    })
  end
end

LrFunctionContext.callWithContext('vscoKeysOptions', function(context)
  local f = LrView.osFactory()
  local properties = LrBinding.makePropertyTable(context)
  local savedSettings = PluginSettings.load() or {}
  local savedHiddenActions = savedSettings.hiddenActions
  local hiddenActions = type(savedHiddenActions) == 'table' and savedHiddenActions or prefs.hiddenActions or {}
  properties.denoiseAmount = tostring(savedSettings.denoiseAmount or prefs.denoiseAmount or 50)
  properties.cropZoomPercent = tostring(savedSettings.cropZoomPercent or prefs.cropZoomPercent or 10)
  properties.actionSearch = ''
  properties.groupsExpanded = true

  for _, command in ipairs(commands) do
    properties['show_' .. command.id] = hiddenActions[command.id] ~= true
    properties['match_' .. command.id] = true
  end
  properties:addObserver('actionSearch', function(propertyTable)
    local query = string.lower(tostring(propertyTable.actionSearch or ''))
    for _, command in ipairs(commands) do
      local searchText = string.lower(command.category .. ' ' .. command.name .. ' ' .. command.id)
      propertyTable['match_' .. command.id] = query == '' or string.find(searchText, query, 1, true) ~= nil
    end
  end)

  local actionViews = {}
  local currentCategory = nil
  local categoryCommands = {}

  local function addCategoryView()
    if not currentCategory then return end
    local scopedCommands = categoryCommands
    local checkboxes = {}
    for _, command in ipairs(scopedCommands) do
      table.insert(checkboxes, f:view {
        visible = LrView.bind('match_' .. command.id),
        f:checkbox {
          title = command.name,
          value = LrView.bind('show_' .. command.id),
        },
      })
    end
    local categoryView = f:group_box {
      title = currentCategory,
      f:column {
        spacing = f:control_spacing(),
        f:view {
          visible = LrView.bind('groupsExpanded'),
          f:column {
            spacing = f:control_spacing(),
            f:row {
              f:push_button {
                title = 'Show category',
                action = function()
                  for _, command in ipairs(scopedCommands) do
                    properties['show_' .. command.id] = true
                  end
                end,
              },
              f:push_button {
                title = 'Hide category',
                action = function()
                  for _, command in ipairs(scopedCommands) do
                    properties['show_' .. command.id] = false
                  end
                end,
              },
            },
            f:column(checkboxes),
          },
        },
      },
    }
    table.insert(actionViews, categoryView)
end

  for _, command in ipairs(commands) do
    if command.category ~= currentCategory then
      addCategoryView()
      currentCategory = command.category
      categoryCommands = {}
    end
    table.insert(categoryCommands, command)
  end
  addCategoryView()

  local actionColumn = {fill_horizontal = 1}
  for _, actionView in ipairs(actionViews) do
    table.insert(actionColumn, actionView)
  end

  local contents = f:view {
    bind_to_object = properties,
    f:tab_view {
      f:tab_view_item {
        title = 'Defaults',
        identifier = 'defaults',
        f:column {
          spacing = f:control_spacing(),
          f:row {
            f:static_text { title = 'Filter' },
            f:edit_field {
              value = LrView.bind('actionSearch'),
              width_in_chars = 56,
              fill_horizontal = 1,
            },
          },
          f:row {
            f:static_text { title = 'Default Denoise Amount', width = 190 },
            f:edit_field {
              value = LrView.bind('denoiseAmount'),
              width_in_chars = 8,
            },
          },
          f:static_text {
            title = 'Used by the Enable Denoise command. Enter a value from 1 to 100.',
          },
          f:row {
            f:static_text { title = 'Crop Zoom Step (%)', width = 190 },
            f:edit_field {
              value = LrView.bind('cropZoomPercent'),
              width_in_chars = 8,
            },
          },
          f:static_text {
            title = 'Zoom percentage for Crop Zoom In/Out. E.g., 10 = 10% change per step. Used when no parameter is sent.',
          },
        },
      },
      f:tab_view_item {
        title = 'Visible actions',
        identifier = 'visibleActions',
        f:column {
          spacing = f:control_spacing(),
          f:row {
            f:push_button {
              title = 'Show all',
              action = function()
                for _, command in ipairs(commands) do
                  properties['show_' .. command.id] = true
                end
              end,
            },
            f:push_button {
              title = 'Hide all',
              action = function()
                for _, command in ipairs(commands) do
                  properties['show_' .. command.id] = false
                end
              end,
            },
            f:push_button {
              title = 'Fold all groups',
              action = function() properties.groupsExpanded = false end,
            },
            f:push_button {
              title = 'Unfold all groups',
              action = function() properties.groupsExpanded = true end,
            },
          },
          f:scrolled_view {
            width = 940,
            height = 640,
            f:column(actionColumn),
          },
        },
      },
    },
  }

  local result = LrDialogs.presentModalDialog {
    title = 'VSCO Keys Settings',
    contents = contents,
    actionVerb = 'Save',
  }

  if result ~= 'ok' then return end

  local denoiseAmount = tonumber(properties.denoiseAmount)
  if not denoiseAmount or denoiseAmount < 1 or denoiseAmount > 100 then
    LrDialogs.message('Default Denoise Amount must be a number from 1 to 100.', 'Invalid setting', 'warning')
    return
  end

  local cropZoomPercent = tonumber(properties.cropZoomPercent)
  if not cropZoomPercent or cropZoomPercent < 1 or cropZoomPercent > 100 then
    LrDialogs.message('Crop Zoom Step must be a number from 1 to 100.', 'Invalid setting', 'warning')
    return
  end
  denoiseAmount = math.floor(denoiseAmount + 0.5)

  local nextHiddenActions = {}
  for _, command in ipairs(commands) do
    if properties['show_' .. command.id] ~= true then
      nextHiddenActions[command.id] = true
    end
  end

  prefs.denoiseAmount = denoiseAmount
  prefs.cropZoomPercent = cropZoomPercent
  prefs.hiddenActions = nextHiddenActions
  local settings = {
    denoiseAmount = denoiseAmount,
    cropZoomPercent = cropZoomPercent,
    hiddenActions = nextHiddenActions,
  }
  local settingsSaved, settingsError = PluginSettings.save(settings)
  if not settingsSaved then
    LrDialogs.message('Settings were saved in Lightroom, but not to the shared VSCO Keys settings file: ' .. tostring(settingsError), 'Settings file warning', 'warning')
  end
  local payload = JSON:encode {
    denoiseAmount = denoiseAmount,
    hiddenActions = nextHiddenActions,
  }
  LrTasks.startAsyncTask(function()
    local response = LrHttp.post(settingsEndpoint, payload, {
      {field = 'Content-Type', value = 'application/json'},
    })
    if not response then
      LrDialogs.message('Settings were saved, but VSCO Keys is not running. Changes will sync when it reconnects.', 'Settings saved', 'warning')
    end
  end)
end)