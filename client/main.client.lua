_G.Client = script.Parent

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage.Source:WaitForChild("InitializeEnvironment"))

local Maid = require(shared.Common.Maid)
local NetworkLib = require(shared.Common.NetworkLib)
local GameEnum = shared.GameEnum


---Client instance hosting a bunch of things...
---@class Client
local Client = {}
Client.__index = Client

function Client.new()
    local self = {
        Mouse = Players.LocalPlayer:GetMouse(),

        Paused = false
    }

    setmetatable(self, Client)
    Maid.watch(self)

    return self
end

function Client:start(module, options)
    self._running = require(module)(self, options)

    NetworkLib:send(GameEnum.PacketType.Ready)
    return self
end

local client = Client.new()
client:start(_G.Client.Game.MinesweeperClient)