local TableUtils = require(shared.Common.TableUtils)

---@class PacketType
local GameEnum = {
    {"Begin", "Send starting parameters"},
    {"InProgress", ""},
    {"GameOver", ""},
    {"CleanUp", ""}
}

return TableUtils.toEnumList(script.Parent.Name, GameEnum)
