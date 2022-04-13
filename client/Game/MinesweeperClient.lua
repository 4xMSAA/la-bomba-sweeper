local CURSOR_UPDATE_TICK = _G.TIMERS.CURSOR_UPDATE
local CAMERA_SENSITIVITY_X = _G.CAMERA.SENSITIVITY.X
local CAMERA_SENSITIVITY_Y = _G.CAMERA.SENSITIVITY.Y
local ZOOM_MAX_SCROLL = _G.CAMERA.ZOOM.MAX_SCROLLS
local ZOOM_PERCENTAGE = _G.CAMERA.ZOOM.PERCENTAGE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local GameEnum = shared.GameEnum

local Maid = require(shared.Common.Maid)
local Timer = require(shared.Common.Timer)
local NetworkLib = require(shared.Common.NetworkLib)
local Sound = require(shared.Common.Sound)
local log, logwarn = require(shared.Common.Log)(script:GetFullName())

local Board = require(shared.Game.Board)

local CursorUpdateTimer = Timer.new(CURSOR_UPDATE_TICK)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
raycastParams.IgnoreWater = true


local function playSound(game, folder)
    local len = #folder:GetChildren()
    local sound = folder:GetChildren()[math.random(len)]
    
    if not game.Sounds[sound] then
        game.Sounds[sound] = Sound.fromInstance(sound, {Parent = _G.Path.Sounds})
    end

    game.Sounds[sound]:play()
end

local function placeFlag(game, state)
    if game.GameState == GameEnum.GameState.InProgress then
        local tile = game.Board:mouseToBoard(game.Client.Mouse.Hit.Position)
        if tile and game.Board:getTile(tile.X, tile.Y) == -1 then
            local isFlagged, flagState = game.Board:isFlagged(tile.X, tile.Y)
            if state ~= nil then
                flagState = state
            else
                flagState = not game.Board:isFlagged(tile.X, tile.Y)
            end

            if flagState ~= isFlagged then
                if flagState then
                    playSound(game, shared.Assets.Sounds.Flag)
                end
                game.Board:setFlag(tile.X, tile.Y, flagState, Players.LocalPlayer)
                NetworkLib:send(GameEnum.PacketType.SetFlagState, tile.X, tile.Y, flagState)
                game.Board:render()
            end
            
            return flagState
        end
    end
end

local function sweep(game)
    if game.GameState == GameEnum.GameState.InProgress then
        local tile = game.Board:mouseToBoard(game.Client.Mouse.Hit.Position)
        if tile and game.Board:getTile(tile.X, tile.Y) == -1 and not game.Board:isFlagged(tile.X, tile.Y) then
            playSound(game, shared.Assets.Sounds.Discover)
            game.Board.Discovered[tile.X][tile.Y] = -2 -- put it into a "pending" state on the client
            NetworkLib:send(GameEnum.PacketType.Discover, tile.X, tile.Y)
        end
    end
end

local function updateMouseHover(game)
    if game.GameState == GameEnum.GameState.InProgress or game.GameState == GameEnum.GameState.CleanUp then
        local mouseLocation = UserInputService:GetMouseLocation()
        local tile = game.Board:mouseToBoard(game.Client.Mouse.Hit.Position)
        local flagInfo = game.Gui.FlagInfo

        -- flag info
        if tile and game.Board:isFlagged(tile.X, tile.Y) then
            local flag = game.Board:getFlag(tile.X, tile.Y)
            flagInfo.DisplayName.Text = flag.Owner.DisplayName
            flagInfo.Position = UDim2.new(0, mouseLocation.X, 0, mouseLocation.Y)
            flagInfo.Visible = flag.Owner == Players.LocalPlayer and false or true
        else
            flagInfo.Visible = false
        end
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

        Gui = shared.Assets.Gui.Game:Clone(),
        
        Sounds = {},

        _binds = {},
        _state = {},
    }

    setmetatable(self, MinesweeperClient)
    Maid.watch(self)
    
    self.Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    self.Camera:addOffset(1, CFrame.new())
    self.Camera:addOffset(2, CFrame.new())

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
    
    self.Camera.FieldOfView = 30
    self.Board = Board.new()
    self.GameState = GameEnum.GameState.InProgress
    self._state.CameraHeight = 100 -- TODO: calculate
    self._state.Scrolls = 0
    self._state.CameraCFrame = CFrame.new()

    self.Board:render()
    raycastParams.FilterDescendantsInstances = {self.Board:getRenderModel()}

    self.Camera:updateOffset(1, self._state.CameraCFrame)
    self.Camera:updateOffset(2, CFrame.new())
    self.Camera:setCFrame(CFrame.new(0, self._state.CameraHeight, 0) * CFrame.Angles(-math.pi/2, 0, 0))

    print(self.Playing)
    self.Gui:WaitForChild("Screen"):WaitForChild("SpectatingBar").Visible = not self:isPlaying()
end

function MinesweeperClient:gameEnd(victory, extraData)
    
    self.GameState = GameEnum.GameState.CleanUp
    if victory then
        self.Board.Mines = extraData.Mines
    else
        self.Board.Mines = extraData.Mines
        self.Board.ExplosionAt = extraData.ExplosionAt
    end

    self.Board:render()
    task.wait(5)
    self.GameState = GameEnum.GameState.GameOver
    self.Board:destroy()
    
end

function MinesweeperClient:bindInput()
    ContextActionService:UnbindAllActions()

    self._state.Scrolls = 0
    local dragCamera, sweeping = false, false
    local flaggingState = false
    local function inputHandler(name, state, object)
        local boolState = state == Enum.UserInputState.Begin and true or false
        if boolState then
            if self.GameState == GameEnum.GameState.InProgress and self:isPlaying() then
                if name == "PlaceFlag" then
                    flaggingState = placeFlag(self)
                    updateMouseHover(self)
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
                flaggingState = nil
            elseif name == "Discover" then
                sweeping = false
            end
        end
        
        if name == "MoveCamera" then
            dragCamera = boolState
            UserInputService.MouseBehavior = 
                boolState and Enum.MouseBehavior.LockCurrentPosition 
                or Enum.MouseBehavior.Default
        end
    end
    
    local function inputChangedHandler(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if dragCamera then
                self._state.CameraCFrame = 
                    self._state.CameraCFrame *
                    CFrame.new(input.Delta.X * CAMERA_SENSITIVITY_X, -input.Delta.Y * CAMERA_SENSITIVITY_Y, 0)
                self.Camera:updateOffset(1, self._state.CameraCFrame)
            end
            if flaggingState ~= nil then 
                placeFlag(self, flaggingState)
            elseif sweeping then
                sweep(self)
            end
            updateMouseHover(self)
        elseif input.UserInputType == Enum.UserInputType.MouseWheel then
                if input.Position.Z > 0 then
                    self._state.Scrolls = math.min(ZOOM_MAX_SCROLL, self._state.Scrolls + 1)
                elseif input.Position.Z < 0 then
                    self._state.Scrolls = math.max(0, self._state.Scrolls - 1)
                end 
                self.Camera:updateOffset(2, CFrame.new(0, 0, -self._state.Scrolls * (self._state.CameraHeight * ZOOM_PERCENTAGE)))
        end
    end
    
    UserInputService.InputChanged:Connect(inputChangedHandler)

    ContextActionService:BindAction("PlaceFlag", inputHandler, true, Enum.UserInputType.MouseButton2)
    ContextActionService:BindAction("Discover", inputHandler, true, Enum.UserInputType.MouseButton1)
    ContextActionService:BindAction("MoveCamera", inputHandler, true, Enum.UserInputType.MouseButton3)
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
        -- self.Cursors[player] = Vector2.new(x, z)
    elseif packet == GameEnum.PacketType.SetFlagState then
        local x, y, state, owner = args[1], args[2], args[3], args[4]
        self.Board:setFlag(x, y, state, owner)
        self.Board:render()
        
        if owner == Players.LocalPlayer then return end
        playSound(self, shared.Assets.Sounds.Flag)
    elseif packet == GameEnum.PacketType.Discover then
        local boardDiscovered = args[1]
        self.Board.Discovered = boardDiscovered
        self.Board:render()

        playSound(self, shared.Assets.Sounds.Discover)
    elseif packet == GameEnum.PacketType.GameState then
        local enumID = args[1]
        local stateEnum = GameEnum.GameState(enumID)
        if stateEnum == GameEnum.GameState.Begin or stateEnum == GameEnum.GameState.InProgress then
            self:gameBegin(args[2])
            if args[2].Adhoc then
                self.Board.Discovered = args[2].Board.Discovered
                self.Board.Flags = args[2].Board.Flags
                self.Board:render()
            end
        elseif stateEnum == GameEnum.GameState.GameOver then
            self:gameEnd(args[2], args[3])
        end
    elseif packet == GameEnum.PacketType.PlaySound then
        local instance, position = args[1], args[2]
        local sound = Sound.fromInstance(instance, {Parent = _G.Path.Sounds})
        local childSound = sound.Instance:FindFirstChildOfClass("Sound")
        if childSound and childSound:GetAttribute("PlayInstantly") then
            childSound:Play()
        end

        sound.Ended:Connect(function()
            if childSound and not childSound:GetAttribute("PlayInstantly") then
                childSound:Play()
                childSound.Ended:wait()
            end
            sound:destroy()
        end)
        
        if position then
            -- do some magic later on
        end

        sound:play()
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