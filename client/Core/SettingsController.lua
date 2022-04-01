local Maid = require(shared.Common.Maid)

---Watches over configurable settings and updates the values associated with the setting
---@class SettingsController
local SettingsController = {}
SettingsController.__index = SettingsController

---@param tree table A settings tree to watch over
function SettingsController.new(tree)
    local self = {}
    -- TODO: prob have to use some metatable to check for changes or the concept of Redux maybe


    setmetatable(self, SettingsController)
    Maid.watch(self)
    return self
end