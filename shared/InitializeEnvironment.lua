local RunService = game:GetService("RunService")

-- shortcut function to Instance
function _G.create(class, properties)
    local inst = Instance.new(class)
    for prop, value in pairs(properties) do
        inst[prop] = value
    end
    return inst
end

local function createSharedFolder(name, parent)
    return ((RunService:IsServer() and _G.create("Folder", {Name = name, Parent = parent})) or
        parent:WaitForChild(name, _G.LOADING.TIMEOUT) or
        error(name .. " does not exist on client"))
end

if RunService:IsServer() then
    _G.Storage = game:GetService("ServerStorage")
    _G.Assets = _G.Storage:WaitForChild("Assets")
end

shared.Storage = game:GetService("ReplicatedStorage")
shared.Source = shared.Storage:WaitForChild("Source")
shared.Common = shared.Source:WaitForChild("Common")
shared.Game = shared.Source:WaitForChild("Game")
shared.Assets = shared.Storage:WaitForChild("Assets")

-- load final configuration values to _G
for key, data in pairs(require(shared.Source:WaitForChild("Configuration"))) do
    _G[key] = data
end

-- load enums
shared.GameEnum = {}
for _, enumModule in pairs(shared.Source:WaitForChild("GameEnum"):GetChildren()) do
    shared.GameEnum[enumModule.Name] = require(enumModule)
end

-- define global paths we weant quick access to
_G.Workspace = createSharedFolder("GameFolder", workspace)

-- less commonly used accesses
_G.Path = {}

-- both client and server
_G.Path.Remotes = createSharedFolder("Remotes", shared.Storage)

if RunService:IsServer() then
    -- create by server
    _G.create("RemoteEvent", {Name = "Signal", Parent = _G.Path.Remotes})
    _G.create("RemoteFunction", {Name = "Callback", Parent = _G.Path.Remotes})
else
    -- client specific paths
    _G.Path.FX = _G.create("Folder", {Name = "FX", Parent = _G.Workspace})
    _G.Path.Sounds = _G.create("Folder", {Name = "Sounds", Parent = _G.Workspace})
end

return true
