local NetworkLib = require(shared.Common.NetworkLib)

-- TODO: load data to a client in ClientManager

---Holds all information about a connected user
---@class Client
local Client = {}
Client.__index = Client

function Client.new(player)
    local self = {
        Instance = player,
        ID = player.UserId,
        Name = player.Name,
        IsReady = false,
        Data = nil,
        Team = nil
    }

    setmetatable(self, Client)
    return self
end

---Serialize the data for network transfer
function Client:serialize()
    return {
        Instance = self.Instance,
        ID = self.ID,
        Name = self.Name,
        DisplayName = self.Instance.DisplayName
    }
end

return Client