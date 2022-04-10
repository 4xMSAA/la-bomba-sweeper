local Object = {}
local Maid -- attain context from runtime

function Object.destroy(self)
    task.wait()
    -- for _, value in pairs(self) do
    --     if typeof(value) == "table" then
    --         if not value["__MAID_DONOTCLEAR"] then
    --             Object.destroy(value)
    --         end
    --     end
    -- end

    if self._maidMetadata then
        if self._maidMetadata.flush then
            self._maidMetadata.flush(self)
        end
        if self._maidMetadata.destroy then
            self._maidMetadata.destroy(self)
        end
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