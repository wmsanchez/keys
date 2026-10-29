--[[----------------------------------------------------------------------------

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

require "Client"
local logging = require "Logging"
local LrTasks = import "LrTasks"
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrShell = import "LrShell"

if (LOCK_VSCOS_KEYS_INIT) then
  return
end

LOCK_VSCOS_KEYS_INIT = true
logging:log("init happened.")

-- Load up registered applications (auto-launch)
if (LrFileUtils.exists(_PLUGIN.path .. "/apps")) then
  logging:log("booting apps:")
  LrTasks.startAsyncTask( function ()
    if (LrFileUtils.exists(_PLUGIN.path .. "/apps/VSCOKeys.app")) then
      LrShell.openFilesInApp({LrPathUtils.child(_PLUGIN.path, "Info.lua")}, LrPathUtils.child(_PLUGIN.path, "apps/VSCOKeys.app"))
      logging:log("launched VSCOKeys.app")
    else
      logging:log("VSCOKeys.app not found in apps/")
    end
  end, "Start external apps")
end

Client:auth( function()
  Client:init()
end)
