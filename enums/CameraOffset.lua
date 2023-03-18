local TableUtils = require(shared.Common.TableUtils)

---@class CameraOffset
local GameEnum = {
    {"Animation", "Affected by animating the camera"},
}

return TableUtils.toEnumList(script.Parent.Name, GameEnum)
