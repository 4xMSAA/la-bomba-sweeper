local TableUtils = require(shared.Common.TableUtils)

---@class PacketType
local GameEnum = {
    {"Start", "Send starting parameters"},
    {"InProgress", ""},
    {"End", ""}
}

return TableUtils.toEnumList(script.Parent.Name, GameEnum)
