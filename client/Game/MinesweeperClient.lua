local CURSOR_UPDATE_TICK = _G.TIMERS.CURSOR_UPDATE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local GameEnum = shared.GameEnum

local Maid = require(shared.Common.Maid)
local Timer = require(shared.Common.Timer)
local NetworkLib = require(shared.Common.NetworkLib)

print(CURSOR_UPDATE_TICK)
local CursorUpdateTimer = Timer.new(CURSOR_UPDATE_TICK)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
raycastParams.IgnoreWater = true

---A class description
---@class MinesweeperClient
local MinesweeperClient = {}
MinesweeperClient.__index = MinesweeperClient

function MinesweeperClient.new(client, options)
    local self = {
        Client = client,
        Options = options,
        Camera = require(_G.Client.Core.Camera).new(workspace.CurrentCamera),
        Playing = {},
        Board = nil,

        _binds = {},
        _state = {},
    }

    setmetatable(self, MinesweeperClient)
    Maid.watch(self)

    return self
end

function MinesweeperClient:gameBegin(players)

    self.Playing = players

    
    self.Board = Board.new()

    self.GameState = GameEnum.GameState.InProgress
    
    self.Board:render()
    raycastParams.FilterDescendantsInstances = {self.Board:getRenderModel()}
    
    self.Camera.CFrame = CFrame.new(0, 100, 0) * CFrame.Angles(math.pi/2, 0, 0)
end

function MinesweeperClient:bind()
    self._state.Mouse = Players.LocalPlayer:GetMouse()
    self._state.CursorLastPosition = UserInputService:GetMouseLocation()

    -- runservice binds
    self._binds.Cursor = RunService:BindToRenderStep(
        "CursorsUpdate",
        500,
        function(dt)
            if self.Client.Paused then return end
            if CursorUpdateTimer:tick(dt) then
                if self._state.CursorLastPosition == UserInputService:GetMouseLocation() then return end
                self._state.CursorLastPosition = UserInputService:GetMouseLocation()

                NetworkLib:send(GameEnum.PacketType.CursorUpdate, self._state.Mouse.Hit.Position)
            end
        end
    )

    self._binds.Camera = RunService:BindToRenderStep(
        "CameraUpdate",
        100,
        function(dt)
            if self.Client.Paused then return end

            debug.profilebegin("game-camera")
            self.Camera:updateView(dt)
            debug.profileend("game-camera")
        end
    )
end

function MinesweeperClient:route(...)
    NetworkLib:listenFor(GameEnum.PacketType.CursorUpdate, function(player, x, y, z) 
        self.Cursors[player] = Vector3.new(x, y, z)
    end)
end

return function(client, options)
    local game = MinesweeperClient.new(client, options)
    game:bind()

    NetworkLib:listenFor(GameEnum.PacketType.GameState, function(enum)
        if enum == GameEnum.GameState.Begin or enum == GameEnum.GameState.InProgress then
            game:gameBegin()
        end
    end)
end