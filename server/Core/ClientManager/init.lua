--[[
    Handle new incoming connections
--]]
local Maid = require(shared.Common.Maid)
local GameEnum = shared.GameEnum
local log, logwarn = require(shared.Common.Log)(script:GetFullName())
local TableUtils = require(shared.Common.TableUtils)


local Players = game:GetService("Players")

local Emitter = require(shared.Common.Emitter)
local Client = require(script.Client)

local JOIN_PROCEDURES_FOLDER = script.JoinProcedures
local LEAVE_PROCEDURES_FOLDER = script.LeaveProcedures

---Orders all modules by their priority value (lower is more critical)
---@param moduleList table A list of modules with a Priority property to order
---                        with
local function orderModulesByPriority(moduleList)
    local orderedList = {}
    for pass = 1, TableUtils.getSize(GameEnum.Priority) do
        for _, module in pairs(moduleList) do
            if module.Priority == GameEnum.Priority(pass) then
                table.insert(orderedList, module)
            end
        end
    end
    
    return orderedList
end

---Handles incoming connections and leaving users
---@class ClientManager
local ClientManager = {}
ClientManager.__index = ClientManager

--- Constructs a new ClientManager
---@param joinProcedures table A table with Procedure data
---@param leaveProcedures table A table with Procedure data
---@return ClientManager
function ClientManager.new(joinProcedures, leaveProcedures)
    local self = {
        Clients = {},
        LeaveProcedures = {},
        JoinProcedures = {},

        ClientAdded = Emitter.new(),
        ClientRemoving = Emitter.new(),
    }

    if not joinProcedures then
        local procedureModules = {}
        for _, procedure in pairs(JOIN_PROCEDURES_FOLDER:GetChildren()) do
            table.insert(procedureModules, require(procedure))
        end
        self.JoinProcedures = orderModulesByPriority(procedureModules)
        log(2, "Loaded JoinProcedures from", JOIN_PROCEDURES_FOLDER:GetFullName(), "- address:", self.JoinProcedures)
    else
        self.JoinProcedures = joinProcedures
    end

    if not leaveProcedures then
        local procedureModules = {}
        for _, procedure in pairs(LEAVE_PROCEDURES_FOLDER:GetChildren()) do
            table.insert(procedureModules, require(procedure))
        end
        self.LeaveProcedures = orderModulesByPriority(procedureModules)
    else
        self.LeaveProcedures = leaveProcedures
    end

    setmetatable(self, ClientManager)
    Maid.watch(self)
    return self
end

--- Initializes extra features in ClientManager (events, connections)
function ClientManager:init()
    self._PlayerAdded =
        Players.PlayerAdded:connect(
        function(player)
            local client = self:addClientByPlayer(player)
            self.ClientAdded:emit(client)
        end
    )
    self._PlayerRemoving =
        Players.PlayerRemoving:connect(
        function(player)
            local client = self:removeClientByPlayer(player)
            self.ClientRemoving:emit(client)
        end
    )

    for _, player in pairs(Players:GetPlayers()) do
        self:addClientByPlayer(player)
    end
end

---
---@param player userdata
function ClientManager:getClientBy(player)
    for _, client in pairs(self.Clients) do
        if client.Instance == player then
            return client
        end
    end
end

function ClientManager:getClientByID(id)
    for _, client in pairs(self.Clients) do
        if client.ID == id then
            return client
        end
    end
end

function ClientManager:getClients(filter)
    if filter then
        local results = {}
        for index, client in pairs(self.Clients) do
            if filter(index, client) then
                table.insert(results, client)
            end
        end    
        return results
    end

    return self.Clients
end

---
---@param client Client
function ClientManager:addClient(client)
    -- run them through modules in JoinProcedures
    -- they have been sorted by priority
    for _, module in pairs(self.JoinProcedures) do
        coroutine.wrap(module.Run)(client)
    end

    table.insert(self.Clients, client)

    return client
end

---
---@param player userdata
function ClientManager:addClientByPlayer(player)
    local client = Client.new(player)

    return self:addClient(client)
end

---
---@param client Client
function ClientManager:removeClient(client)
    -- run them through modules in LeaveProcedures
    for _, module in pairs(self.LeaveProcedures) do
        module.Run(client)
    end

    for index, listClient in pairs(self.Clients) do
        if client == listClient then
            table.remove(self.Clients, index)
        end
    end
    return client
end

---
---@param player userdata
function ClientManager:removeClientByPlayer(player)
    local client = self:getClientBy(player)
    self:removeClient(client)
    return client
end

--- Removes all clients but keeps connections and the object
function ClientManager:flush()
    for _, client in pairs(self.Clients) do
        self:removeClient(client)
    end
end

--- Leaves the ClientManager to garbage collection
function ClientManager:destroy()
    self._PlayerAdded:disconnect()
    self._PlayerRemoving:disconnect()

    for property, _ in pairs(self) do
        self[property] = nil
    end
end

return ClientManager
