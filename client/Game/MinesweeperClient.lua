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
local log, logwarn = require(shared.Common.Log)(script:GetFullName())

local Board = require(shared.Game.Board)

local CursorUpdateTimer = Timer.new(CURSOR_UPDATE_TICK)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
raycastParams.IgnoreWater = true


local function placeFlag(game, state)
    local tile = game.Board:mouseToBoard(game.Client.Mouse.Hit.Position)
    if tile then
        local flagState
        if state ~= nil then
            flagState = state
        else
            flagState = not game.Board:isFlagged(tile.X, tile.Y)
        end

        game.Board:setFlag(tile.X, tile.Y, flagState, Players.LocalPlayer)
        NetworkLib:send(GameEnum.PacketType.SetFlagState, tile.X, tile.Y, flagState)
        game.Board:render()
        
        return flagState
    end
end

local function sweep(game)
    local tile = game.Board:mouseToBoard(game.Client.Mouse.Hit.Position)
    if tile and game.Board:getTile(tile.X, tile.Y) == -1 and not game.Board:isFlagged(tile.X, tile.Y) then
        game.Board.Discovered[tile.X][tile.Y] = -2 -- put it into a "pending" state on the client
        NetworkLib:send(GameEnum.PacketType.Discover, tile.X, tile.Y)
    end
end

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

function MinesweeperClient:isPlaying()
    for _, player in pairs(self.Playing) do
        if player == Players.LocalPlayer then
            return true
        end
    end

    return false
end

function MinesweeperClient:gameBegin(options)

    self.Playing = options.Players or {}
    
    self.Camera:setCFrame(CFrame.new(0, 100, 0) * CFrame.Angles(-math.pi/2, 0, 0))
    self.Camera.FieldOfView = 30
    self.Board = Board.new()
    self.GameState = GameEnum.GameState.InProgress
    
    self.Board:render()
    raycastParams.FilterDescendantsInstances = {self.Board:getRenderModel()}
    
end

function MinesweeperClient:gameEnd(extraData)
    self.Board.Mines = extraData.Mines
    self.Board.ExplosionAt = extraData.ExplosionAt
    self.Board:render()

    task.wait(5)

    self.Board:destroy()
end

function MinesweeperClient:bindInput()
    ContextActionService:UnbindAllActions()

    local flagging, sweeping = false, false
    local flaggingState = false
    local function inputHandler(name, state, object)
        local boolState = state == Enum.UserInputState.Begin and true or false
        if boolState then
            if self.GameState == GameEnum.GameState.InProgress and self:isPlaying() then
                if name == "PlaceFlag" then
                    flagging = true
                    flaggingState = placeFlag(self)
                elseif name == "Discover" then
                    sweeping = true
                    sweep(self)
                end
            end
            if name == "debugPause" then
                self.Client.Paused = not self.Client.Paused
            elseif name == "debugLog" then
                Maid.info()
            end
        else
            if name == "PlaceFlag" then
                flagging = false
            elseif name == "Discover" then
                sweeping = false
            end
        end
    end
    
    local function inputChangedHandler(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and flagging or sweeping then
            if flagging then 
                placeFlag(self, flaggingState)
            elseif sweeping then
                sweep(self)
            end
        end
    end
    
    UserInputService.InputChanged:Connect(inputChangedHandler)

    ContextActionService:BindAction("PlaceFlag", inputHandler, true, Enum.UserInputType.MouseButton2)
    ContextActionService:BindAction("Discover", inputHandler, true, Enum.UserInputType.MouseButton1)
    ContextActionService:BindAction("debugPause", inputHandler, true, Enum.KeyCode.P)
    ContextActionService:BindAction("debugLog", inputHandler, true, Enum.KeyCode.O)
end

function MinesweeperClient:bind()
    self._state.CursorLastPosition = nil

    -- runservice binds
    self._binds.Cursor = RunService:BindToRenderStep(
        "CursorsUpdate",
        500,
        function(dt)
            if self.Client.Paused then return end
            if CursorUpdateTimer:tick(dt) then
                if self._state.CursorLastPosition == UserInputService:GetMouseLocation() then return end
                self._state.CursorLastPosition = UserInputService:GetMouseLocation()
                
                local hitPos = self.Client.Mouse.Hit.Position
                NetworkLib:send(GameEnum.PacketType.CursorUpdate, hitPos.X, hitPos.Z)
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

function MinesweeperClient:route(packet, ...)
    local args = {...}
    if packet == GameEnum.PacketType.CursorUpdate then
        local player, x, z = args[1], args[2], args[3]
        -- self.Cursors[player] = Vector2.new(x, , z)
    end
    
    if packet == GameEnum.PacketType.SetFlagState then
        local x, y, state, owner = args[1], args[2], args[3], args[4]
        self.Board:setFlag(x, y, state, owner)
    end
    
    if packet == GameEnum.PacketType.Discover then
        local boardDiscovered = args[1]
        self.Board.Discovered = boardDiscovered
        self.Board:render()
    end

    if packet == GameEnum.PacketType.GameState then
        local enumID = args[1]
        local stateEnum = GameEnum.GameState(enumID)
        if stateEnum == GameEnum.GameState.Begin or stateEnum == GameEnum.GameState.InProgress then
            self:gameBegin(args[2])
        elseif stateEnum == GameEnum.GameState.GameOver then
            self:gameEnd(args[2])
        end
    end
end

return function(client, options)
    local game = MinesweeperClient.new(client, options)
    game:bind()
    game:bindInput()
    
    NetworkLib:listen(function(packet, ...)
        game:route(packet, ...)
    end)
end