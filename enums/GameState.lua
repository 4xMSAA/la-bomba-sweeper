local TableUtils = require(shared.Common.TableUtils)

---@class PacketType
local GameEnum = {
    {"Begin", "Send starting parameters"},
    {"InProgress", ""},
    {"GameOver", ""},
    {"CleanUp", ""},
    {"Unknown", "No state yet. Usually only happens on client."}
}

return TableUtils.toEnumList(script.Parent.Name, GameEnum)
