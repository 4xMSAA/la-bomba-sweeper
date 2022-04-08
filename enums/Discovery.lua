local TableUtils = require(shared.Common.TableUtils)

---@class PacketType
local GameEnum = {
    {"Safe", "No mines when the user clicked on a tile"},
    {"Ignore", "Ignore the result and don't do anything after it"},
    {"Mine", "Blow up the game field if this is returned"},
    {"Victory", "game win easy gg no re"}
}

return TableUtils.toEnumList(script.Parent.Name, GameEnum)
