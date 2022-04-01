local Object = {}
local Maid -- attain context from runtime

function Object.destroy(self)
    if self._maidMetadata.flush then
        self:flush()
    end
    if self._maidMetadata.destroy then
        self:destroy()
    end

    Maid._tracked[self] = nil
    for key, value in pairs(self) do
        if typeof(value) == "Instance" then
            value:Destroy()
        end
        self[key] = nil
    end
    setmetatable(self, nil)
end
Object.Destroy = Object.destroy

return function(runtimeMaid)
    Maid = runtimeMaid
    return Object
end