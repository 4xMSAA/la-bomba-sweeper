local CURSOR_UPDATE_TICK = _G.TIMERS.CURSOR_UPDATE
local CAMERA_SENSITIVITY_X = _G.CAMERA.SENSITIVITY.X
local CAMERA_SENSITIVITY_Y = _G.CAMERA.SENSITIVITY.Y
local ZOOM_MAX_SCROLL = _G.CAMERA.ZOOM.MAX_SCROLLS
local ZOOM_PERCENTAGE = _G.CAMERA.ZOOM.PERCENTAGE
local VICTORY_MESSAGES = _G.MESSAGES.VICTORY
local FAIL_MESSAGES = _G.MESSAGES.FAIL
local VICTORY_MESSAGE_COLOR = _G.MESSAGES.VICTORY_COLOR
local FAIL_MESSAGE_COLOR = _G.MESSAGES.FAIL_COLOR

local BOARD_UNDISCOVERED = -1
local BOARD_PENDING = -2

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
local CursorManager = require(_G.Client.Game.CursorManager)

local CursorUpdateTimer = Timer.new(CURSOR_UPDATE_TICK)

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
        if tile and game.Board:getTile(tile.X, tile.Y) == BOARD_UNDISCOVERED then
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
        if tile and game.Board:getTile(tile.X, tile.Y) == BOARD_UNDISCOVERED and not game.Board:isFlagged(tile.X, tile.Y) then
            playSound(game, shared.Assets.Sounds.Discover)
            game.Board.Discovered[tile.X][tile.Y] = BOARD_PENDING
            game.Board:render()
            NetworkLib:send(GameEnum.PacketType.Discover, tile.X, tile.Y)
        end
    end
end

local function updateMouseHover(game)
    local flagInfo = game.Gui.InfoBox.FlagInfo
    if game.GameState == GameEnum.GameState.InProgress or game.GameState == GameEnum.GameState.CleanUp and game.Board then
        local mouseLocation = UserInputService:GetMouseLocation()
        local tile = game.Board:mouseToBoard(game.Client.Mouse.Hit.Position)

        -- flag info
        if tile and game.Board:isFlagged(tile.X, tile.Y) then
            local flag = game.Board:getFlag(tile.X, tile.Y)
            flagInfo.DisplayName.Text = flag.Owner.DisplayName
            flagInfo.Position = UDim2.new(0, mouseLocation.X, 0, mouseLocation.Y)
            flagInfo.Visible = flag.Owner == Players.LocalPlayer and false or true
        else
            flagInfo.Visible = false
        end 
    else
        flagInfo.Visible = false
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
        Victory = false,

        Gui = shared.Assets.Gui.Game:Clone(),
        
        Sounds = {},

        _binds = {},
        _state = {
            CameraCFrame = CFrame.new()
        },
    }

    setmetatable(self, MinesweeperClient)
    Maid.watch(self)
    
    self.Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.UI = require(_G.Client.Game.UI)(self)
    self.CursorManager = CursorManager.new(self)
    self.CursorManager:listen()
    
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
    if self.Board and self.Board["destroy"] then
        self.Board:destroy()
    end

    self.Playing = options.Players or {}
    
    self.Camera.FieldOfView = 30
    self.Board = Board.new()
    self.Board.Discovered = options.Discovered
    self.GameState = GameEnum.GameState.InProgress
    self._state.CameraHeight = 100 -- TODO: calculate
    self._state.Scrolls = 0
    self._state.CameraCFrame = CFrame.new()

    self.Board:render()
    self.Victory = false

    self.Camera:updateOffset(1, self._state.CameraCFrame)
    self.Camera:updateOffset(2, CFrame.new())
    self.Camera:setCFrame(CFrame.new(0, self._state.CameraHeight, 0) * CFrame.Angles(-math.pi/2, 0, 0))

    self.Gui:WaitForChild("Screen"):WaitForChild("SpectatingBar").Visible = not self:isPlaying()
end

local function _compose(messages, patterns)
    local message = messages[math.random(#messages)]

    for pattern, value in pairs(patterns or {}) do
        message = message:gsub("%%" .. pattern .. "%%", tostring(value))
    end
    
    return message
end

function MinesweeperClient:gameEnd(victory, extraData)
    self.GameState = GameEnum.GameState.CleanUp

    self.Board.Discovered = extraData.Discovered
    self.Board.Mines = extraData.Mines
    if victory then
        self.Victory = true
        self.UI.createMessage(
            _compose(VICTORY_MESSAGES) .. " (".. ("%.2f"):format(tostring(extraData.TimeTaken)) .. "s)", 
            VICTORY_MESSAGE_COLOR
        )
    else
        self.Board.ExplosionAt = extraData.ExplosionAt
        self.UI.createMessage(
            _compose(FAIL_MESSAGES, {name = extraData.Who.DisplayName}), 
            FAIL_MESSAGE_COLOR
        )
    end

    self.Board:render()
    local board = self.Board
    task.wait(5)
    if self.GameState == GameEnum.GameState.CleanUp then
        self.GameState = GameEnum.GameState.GameOver
        board:destroy()
    end
    
end

function MinesweeperClient:bindInput()
    ContextActionService:UnbindAllActions()

    self._state.Scrolls = 0
    local dragCamera, sweeping = false, false
    local flaggingState = false
    local moveDirX = 0
    local moveDirY = 0

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
        
        if name == "CameraUp" then
            moveDirY = boolState and 1 or 0
        end
        if name == "CameraDown" then
            moveDirY = boolState and -1 or 0
        end
        if name == "CameraRight" then
            moveDirX = boolState and 1 or 0
        end
        if name == "CameraLeft" then
            moveDirX = boolState and -1 or 0
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
            end
            if sweeping then
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
    
    self._binds.CameraWASDControls = RunService:BindToRenderStep(
        "CameraWASDControls", 
        99,
        function(dt)
            dt = math.min(1, dt)
            if self.Client.Paused then return end

            debug.profilebegin("game-wasd-camera")
            self._state.CameraCFrame = 
                self._state.CameraCFrame * 
                CFrame.new(moveDirX * CAMERA_SENSITIVITY_X * dt * 200, moveDirY * CAMERA_SENSITIVITY_Y * dt * 200, 0)
            self.Camera:updateOffset(1, self._state.CameraCFrame)
            debug.profileend("game-wasd-camera")
        end
    )
    
    UserInputService.InputChanged:Connect(inputChangedHandler)

    ContextActionService:BindAction("PlaceFlag", inputHandler, true, Enum.UserInputType.MouseButton2)
    ContextActionService:BindAction("Discover", inputHandler, true, Enum.UserInputType.MouseButton1)
    ContextActionService:BindAction("MoveCamera", inputHandler, true, Enum.UserInputType.MouseButton3)
    ContextActionService:BindAction("debugPause", inputHandler, true, Enum.KeyCode.P)
    ContextActionService:BindAction("debugLog", inputHandler, true, Enum.KeyCode.O)
    ContextActionService:BindAction("CameraUp", inputHandler, true, Enum.KeyCode.W)
    ContextActionService:BindAction("CameraDown", inputHandler, true, Enum.KeyCode.S)
    ContextActionService:BindAction("CameraLeft", inputHandler, true, Enum.KeyCode.A)
    ContextActionService:BindAction("CameraRight", inputHandler, true, Enum.KeyCode.D)
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
                CursorManager:sendWorldCursor()
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

local function _explodeBoard(game, sound)
    if sound.Parent ~= shared.Assets.Sounds.Explode then return end
    game.Board._render.explode = true
    game.Board:render()
end

local function _playSharedSound(game, instance, position)
    local sound = Sound.fromInstance(instance, {Parent = _G.Path.Sounds})
    local childSound = sound.Instance:FindFirstChildOfClass("Sound")
    if childSound and childSound:GetAttribute("PlayInstantly") then
        childSound:Play()
        _explodeBoard(game, instance)
    elseif childSound and childSound:GetAttribute("Delay") then
        coroutine.wrap(function()
            task.wait(childSound:GetAttribute("Delay"))
            childSound:Play()
            _explodeBoard(game, instance)
        end)()
    elseif not childSound then
        _explodeBoard(game, instance)
    end

    sound.Ended:Connect(function()
        if childSound and not childSound:GetAttribute("PlayInstantly") and not childSound:GetAttribute("Delay") then
            _explodeBoard(game, instance)
            childSound:Play()
            childSound.Ended:wait()
        end
        task.wait(childSound and childSound.TimeLength or 1)
        sound:destroy()
    end)
    
    if position then
        -- do some magic later on
    end

    sound:play()
end

function MinesweeperClient:route(packet, ...)
    local args = {...}
    if packet == GameEnum.PacketType.SetFlagState then
        local x, y, state, owner = args[1], args[2], args[3], args[4]
        self.Board:setFlag(x, y, state, owner)
        self.Board:render()
        
        if owner.Instance == Players.LocalPlayer then return end
        playSound(self, shared.Assets.Sounds.Flag)
    elseif packet == GameEnum.PacketType.Discover then
        local owner, boardDiscovered = args[1], args[2]
        self.Board.Discovered = boardDiscovered
        self.Board:render()

        if owner == Players.LocalPlayer then return end
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
        _playSharedSound(self, instance, position)
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