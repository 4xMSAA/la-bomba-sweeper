_G.Server = script.Parent

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Source:WaitForChild("InitializeEnvironment"))

local Maid = require(shared.Common.Maid)
local NetworkLib = require(shared.Common.NetworkLib)

local ClientManager = require(_G.Server.Core.ClientManager)


---A class description
---@class Server
local Server = {}
Server.__index = Server

function Server.new()
    local self = {
        ClientManager = ClientManager.new(),
    }

    setmetatable(self, Server)
    Maid.watch(self)

    return self
end

function Server:start(module, options)
    self.ClientManager:init()
    self._running = require(module)(server, options)

    return self
end


local server = Server.new()
server:start(_G.Server.Game.Minesweeper)
