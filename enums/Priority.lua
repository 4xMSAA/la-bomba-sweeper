local TableUtils = require(shared.Common.TableUtils)

---@class Priority
local GameEnum = {
    {"Critical", ""},
    {"Important", ""},
    {"Normal", ""},
    {"Unimportant", ""},
    {"Last", ""},
}

return TableUtils.toEnumList(script.Parent.Name, GameEnum)