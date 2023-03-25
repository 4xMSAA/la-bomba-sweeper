--[[
    Ease the burden of writing different method names and signal handling

--]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local GameEnum = shared.GameEnum
local log, logwarn = require(shared.Common.Log)(script:GetFullName())

local remotes = _G.Path.Remotes
local isClient = RunService:IsClient()
local isServer = RunService:IsServer()
---
---@class NetworkLib
local NetworkLib = {}
NetworkLib._packetQueue = {}  -- FIFO
NetworkLib._activeListeners = {}
NetworkLib._listeningFor = {}
NetworkLib._queueListener = nil

local function listenQueue(id, ...)
    local receivedEnum = NetworkLib:_toEnum(id)
    if NetworkLib._listeningFor[receivedEnum] then return end

    NetworkLib:_queue(receivedEnum, ...)
end
local function listenQueueServer(player, id, ...)
    local receivedEnum = NetworkLib:_toEnum(id)
    if NetworkLib._listeningFor[receivedEnum] then return end

    NetworkLib:_queue(receivedEnum, player, ...)
end

local function initListenQueue()
    NetworkLib._queueListener = 
        isClient and remotes.Signal.OnClientEvent:Connect(listenQueue) 
        or isServer and remotes.Signal.OnServerEvent:Connect(listenQueueServer)
end

local function loadQueue(enum, callback, passthrough)
    local packetData = NetworkLib:_dequeue(enum, passthrough)
    if not packetData then return end

    if isClient then
        callback(unpack(packetData))
    elseif isServer and not passthrough then
        local player = table.remove(packetData, 1)
        callback(player, enum, unpack(packetData))
    elseif isServer and passthrough then
        local player = packetData[1]
        local copy = {}
        for i,v in pairs(packetData) do
            if i > 1 then
                table.insert(copy, v)
            end
        end
        callback(player, enum, unpack(copy))
    end
end

-- TODO: queue packets with listenFor and consume, pass through with listen
function NetworkLib:_queue(enum, ...)
    self._packetQueue[enum] = self._packetQueue[enum] or {}
    table.insert(self._packetQueue[enum], {...})
end

function NetworkLib:_dequeue(enum, passthrough)
    self._packetQueue[enum] = self._packetQueue[enum] or {}

    if #self._packetQueue[enum] < 1 then return end

    return passthrough and self._packetQueue[enum][1] or table.remove(self._packetQueue[enum], 1)
end

function NetworkLib:_toEnum(id)
    return GameEnum.PacketType(id)
end

function NetworkLib:_toInstance(object)
    return typeof(object) == "table" and object.Instance or object
end

---Scans through data and if entries contain a table with a :serialize() method,
---changes the entry into the serialized variant
function NetworkLib:_autoSerialize(...)
    if #{...} == 0 then return end

    local result = {}

    log(3, "SERIALIZE: automatically serializing contents:", ...)
    for key, value in pairs({...}) do
        log(3, "SERIALIZE: GOT", key, "=", value)

        if typeof(value) == "table" and value["serialize"] then
            value = value:serialize()
        elseif typeof(value) == "table" and value["new"] ~= nil then
            logwarn(1, "no serialize function on object: " .. tostring(value) .. "\n" .. debug.traceback())
        end

        log(3, "SERIALIZE: ASSIGN", key, "=", value)
        result[key] = value
    end

    log(3, "SERIALIZE: serialized contents:", unpack(result))

    return unpack(result)
end

function NetworkLib:_listenHandler(ev, callback, listenFor)
    local signal

    -- bad spaghetti that will handle server-client communication in one module
    if isClient then
        signal =
            ev:connect(
            function(id, ...)
                local passthrough = nil
                local receivedEnum = NetworkLib:_toEnum(id)
                log(3, "LISTEN: enum: ", receivedEnum and receivedEnum.Name or "nil", "contents:", ...)
                if listenFor and receivedEnum == listenFor then
                    passthrough = callback(...)
                    loadQueue(receivedEnum, callback, passthrough)
                elseif not listenFor then
                    passthrough = callback(receivedEnum, ...)
                    loadQueue(receivedEnum, callback, passthrough or true)
                end
            end
        )
    elseif isServer then
        signal =
            ev:connect(
            function(player, id, ...)
                local passthrough = nil
                local receivedEnum = NetworkLib:_toEnum(id)
                log(3, "LISTEN: from:", player, "enum:", receivedEnum and receivedEnum.Name or "nil", "contents:", ...)
                if listenFor and receivedEnum == listenFor then
                    passthrough = callback(player, ...)
                    loadQueue(receivedEnum, callback, passthrough)
                elseif not listenFor then
                    passthrough = callback(player, receivedEnum, ...)
                    loadQueue(receivedEnum, callback, passthrough or false)
                end
            end
        )
    end

    -- register the signal
    NetworkLib._activeListeners[signal] = callback
    if listenFor then NetworkLib._listeningFor[listenFor] = true end

    -- dequeue all packets regarding the enum

    -- TODO: figure out how to handle disconnnects, observe behaviour if
    -- disconnect makes signal nil or keeps reference?

    return signal
end

function NetworkLib:_init()
    initListenQueue()
end

---Catch-all signal
---@param callback function Executed whenever a signal is received
---@return userdata RbxScriptSignal
function NetworkLib:listen(callback)
    if isClient then
        return NetworkLib:_listenHandler(remotes.Signal.OnClientEvent, callback)
    else
        return NetworkLib:_listenHandler(remotes.Signal.OnServerEvent, callback)
    end
end

---Listen for specific signals with their marked enumerator
---@param enum userdata Enumerable to filter for
---@param callback function Executed whenever a signal is received
---@return userdata RbxScriptSignal
function NetworkLib:listenFor(enum, callback)
    if isClient then
        return NetworkLib:_listenHandler(remotes.Signal.OnClientEvent, callback, enum)
    else
        return NetworkLib:_listenHandler(remotes.Signal.OnServerEvent, callback, enum)
    end
end

---On client, sends to server
---On server, sends to all clients
---@param enum PacketType
function NetworkLib:send(enum, ...)
    if isClient then
        log(3, "CLIENT SEND:", enum.Name, ...)
        remotes.Signal:FireServer(enum.ID, NetworkLib:_autoSerialize(...))
    elseif isServer then
        log(3, "SERVER SEND:", enum.Name, ...)
        remotes.Signal:FireAllClients(enum.ID, NetworkLib:_autoSerialize(...))
    end
end

---
---@param player userdata
---@param enum PacketType
function NetworkLib:sendTo(player, enum, ...)
    if isClient then
        error("cannot send to player on client", 2)
    end
    log(3, "SERVER SEND TO " .. player.Name .. ":", enum.Name, ...)
    remotes.Signal:FireClient(NetworkLib:_toInstance(player), enum.ID, NetworkLib:_autoSerialize(...))
end

---
---@param player userdata
---@param enum PacketType
function NetworkLib:sendToExcept(player, enum, ...)
    if isClient then
        error("cannot send to except player on client", 2)
    end
    log(3, "SERVER SEND TO (except " .. player.Name .. "):", enum.Name, ...)
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= NetworkLib:_toInstance(player) then
            remotes.Signal:FireClient(otherPlayer, enum.ID, NetworkLib:_autoSerialize(...))
        end
    end
end

NetworkLib:_init()

return NetworkLib
