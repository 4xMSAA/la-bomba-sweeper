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
local TableUtils = require(shared.Common.TableUtils)

local log, logwarn = require(shared.Common.Log)(script:GetFullName())

local Board = require(shared.Game.Board)
local CursorManager = require(_G.Client.Game.CursorManager)
local Cursor = require(_G.Client.Game.Cursor)
local SevenSegment = require(_G.Client.Render.SevenSegment)
local Panel = require(_G.Client.Render.Panel)

local CursorUpdateTimer = Timer.new(CURSOR_UPDATE_TICK)

local firstGame = true

local function playSound(game, folder)
    local len = #folder:GetChildren()
    local sound = folder:GetChildren()[math.random(len)]

    if not game.Sounds[sound] then
        game.Sounds[sound] = Sound.fromInstance(sound, {Parent = _G.Path.Sounds})
    end

    game.Sounds[sound]:play()
end

local function _compose(messages, patterns)
    local message = messages[math.random(#messages)]

    for pattern, value in pairs(patterns or {}) do
        message = message:gsub("%%" .. pattern .. "%%", tostring(value))
    end

    return message
end

local function _moveCamera(game, input)
    game._state.CameraCFrame =
        game._state.CameraCFrame *
        CFrame.new(input.X * CAMERA_SENSITIVITY_X, -input.Y * CAMERA_SENSITIVITY_Y, 0)
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = game._state.CameraCFrame:components()
    local extents = game.BoardLastKnownExtents
    local pos = game.BoardLastKnownPosition
    local boundX = math.min(
        math.max(
            pos.X - extents.X / 2, x
        ),
        pos.X + extents.X / 2
    )
    local boundY = math.min(
        math.max(
            pos.Z - extents.Z / 2, y
        ),
        pos.Z + extents.Z / 2
    )

    game._state.CameraCFrame = CFrame.new(boundX, boundY, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
    game.Camera:updateOffset(1, game._state.CameraCFrame)
end

local function _explodeBoard(game, sound)
    if sound.Parent ~= shared.Assets.Sounds.Explode then return end
    game.Board._render.explode = true
    game.Board:render()
end

local function _playSharedSound(game, instance, position)
    local sound = Sound.fromInstance(instance, {Parent = _G.Path.Sounds})
    local childGui = sound.Instance:FindFirstChildOfClass("ScreenGui")
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

    if childGui then
        childGui:Clone().Parent = game.Gui.Parent
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

local function patchNetworkedBoard(locallyDiscovered, networkDiscovered)
    for x, row in pairs(networkDiscovered) do
        for y, tile in pairs(row) do
            locallyDiscovered[x][y] = tile > BOARD_UNDISCOVERED and tile or locallyDiscovered[x][y]
        end
    end

    return locallyDiscovered
end

local function placeFlag(game, state, tilePos)
    if game.GameState == GameEnum.GameState.InProgress then
        local tileLocation = tilePos or game.Board:mouseToBoard(game.Client.Mouse.Hit.Position)
        if not tileLocation then return end
        local tileResult = game.Board:getTile(tileLocation.X, tileLocation.Y)

        if tileLocation and game.Board:getTile(tileLocation.X, tileLocation.Y) == BOARD_UNDISCOVERED then
            local isFlagged, flagState = game.Board:isFlagged(tileLocation.X, tileLocation.Y)
            if state ~= nil then
                flagState = state
            else
                flagState = not game.Board:isFlagged(tileLocation.X, tileLocation.Y)
            end

            if flagState ~= isFlagged then
                if flagState then
                    playSound(game, shared.Assets.Sounds.Flag)
                end
                game.Board:setFlag(tileLocation.X, tileLocation.Y, flagState, Players.LocalPlayer)
                NetworkLib:send(GameEnum.PacketType.SetFlagState, tileLocation.X, tileLocation.Y, flagState)
                game.Board:render()
            end
            return flagState

        elseif tileLocation and tileResult > 0 and state == nil then
            local tiles = game.Board:getNearbyTiles(tileLocation.X, tileLocation.Y)

            local undiscoveredCount = 0
            local flagCount = 0
            for _, tile in pairs(tiles) do
                undiscoveredCount = tile.meta == BOARD_UNDISCOVERED and undiscoveredCount + 1 or undiscoveredCount
                flagCount = game.Board:isFlagged(tile.X, tile.Y) and flagCount + 1 or flagCount
            end

            if undiscoveredCount > tileResult or undiscoveredCount == 0 or flagCount == undiscoveredCount then return end

            playSound(game, shared.Assets.Sounds.Flag)

            for _, tile in pairs(tiles) do
                if tile.meta == BOARD_UNDISCOVERED and not game.Board:isFlagged(tile.X, tile.Y) then
                    game.Board:setFlag(tile.X, tile.Y, true, Players.LocalPlayer)
                    NetworkLib:send(GameEnum.PacketType.SetFlagState, tile.X, tile.Y, true)
                end
            end
            game.Board:render()

            return
        end
    end
end

local function moveSelection(game, direction)
    local self = game
    Cursor.LocalCursor.Visible = true

    Cursor.LocalCursor:move(self.Board, direction)
    self.Board:render()
    self.Board:renderCursors(self.CursorManager.Cursors)
end

local function sweep(game, holding, tilePos)
    if game.GameState == GameEnum.GameState.InProgress then
        local tileLocation = tilePos or game.Board:mouseToBoard(game.Client.Mouse.Hit.Position)
        if not tileLocation then return end
        local tileResult = game.Board:getTile(tileLocation.X, tileLocation.Y)

        if tileLocation and tileResult == BOARD_UNDISCOVERED and not game.Board:isFlagged(tileLocation.X, tileLocation.Y) then
            playSound(game, shared.Assets.Sounds.Discover)
            game.Board.Discovered[tileLocation.X][tileLocation.Y] = BOARD_PENDING
            game.Board:render()
            NetworkLib:send(GameEnum.PacketType.Discover, tileLocation.X, tileLocation.Y)

        elseif tileLocation and tileResult > 0 and holding == nil then
            local tiles = game.Board:getNearbyTiles(tileLocation.X, tileLocation.Y)

            local flagCount = 0
            for _, tile in pairs(tiles) do
                if game.Board:isFlagged(tile.X, tile.Y) then
                    flagCount = game.Board:isFlagged(tile.X, tile.Y) and flagCount + 1 or flagCount
                end
            end

            if flagCount < tileResult or flagCount == 0 then return end

            playSound(game, shared.Assets.Sounds.Discover)

            for _, tile in pairs(tiles) do
                if tile.meta == BOARD_UNDISCOVERED and not game.Board:isFlagged(tile.X, tile.Y) then
                    game.Board.Discovered[tile.X][tile.Y] = BOARD_PENDING
                    NetworkLib:send(GameEnum.PacketType.Discover, tile.X, tile.Y)
                end
            end
            game.Board:render()
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
        Victory = false,
        CursorManager = CursorManager.new(self),

        GameState = GameEnum.GameState.Unknown,

        Displays = {
            Timer = SevenSegment.new(30, _G.Path.FX),
            Flags = SevenSegment.new(4, _G.Path.FX),
        },

        Panels = {
            Board = Panel.new(),
        },

        Gui = shared.Assets.Gui.Game:Clone(),

        Sounds = {},

        _binds = {},
        _state = {
            CameraCFrame = CFrame.new()
        },
    }

    setmetatable(self, MinesweeperClient)
    Maid.watch(self)

    self.Displays.Timer.AnchorPoint = Vector2.new(0, 0)
    self.Displays.Flags.AnchorPoint = Vector2.new(1, 0)

    self.Panels.Board.AnchorPoint = Vector2.new(0.5, 0)

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


function MinesweeperClient:gameBegin(gameInfo)
    if self.Board and self.Board["destroy"] then
        self.Board:destroy()
    end

    self.Playing = gameInfo.Players or {}

    self.Camera.FieldOfView = 30
    self.Board = Board.new()
    for property, value in pairs(gameInfo.Board) do
        self.Board[property] = value
    end

    self.GameState = GameEnum.GameState.InProgress
    self._state.CameraHeight = 105 -- TODO: calculate


    self.Board:render()
    self.Victory = false

    local halfSize = self.Board.Options.Size / 2
    Cursor.LocalCursor:set(Vector2.new(math.ceil(halfSize.X), math.ceil(halfSize.Y)))
    self.Board:renderCursors(self.CursorManager.Cursors)

    if firstGame then
        self._state.CameraCFrame = CFrame.new(0, 1.8, 0)
        self._state.Scrolls = 0
        self.Camera:updateOffset(1, self._state.CameraCFrame)
        self.Camera:updateOffset(2, CFrame.new())
        self.Camera:setCFrame(CFrame.new(0, self._state.CameraHeight, 0) * CFrame.Angles(-math.pi/2, 0, 0))
    end

    self.Gui:WaitForChild("Screen"):WaitForChild("SpectatingBar").Visible = not self:isPlaying()

    local extents = self.Board:getExtents()
    local position = self.Board:getPosition()
    local timerCF = CFrame.new(position.X + extents.X / 2, position.Y, position.Z - extents.Z / 2 - 1)
    local flagsCF = CFrame.new(position.X - extents.X / 2, position.Y, position.Z - extents.Z / 2 - 1)

    self.Displays.Timer:setCFrame(timerCF)
    self.Displays.Flags:setCFrame(flagsCF)

    local displaySizeY = self.Displays.Timer:getSize().Z

    self.Panels.Board:setSizeWithBorder(Vector2.new(extents.X, extents.Z + displaySizeY + 1))
    self.Panels.Board:setCFrame(position * CFrame.new(0, 0, extents.Z / 2 + self.Panels.Board:getBorderSize()) * CFrame.new(0, -1, 0))

    self.Panels.Board.Instance.Parent = _G.Path.FX

    self.Displays.Flags:update(self.Board.MineCount - TableUtils.getSize(self.Board.Flags))

    self.BoardLastKnownExtents = self.Board:getExtents()
    self.BoardLastKnownPosition = self.Board:getPosition()

    firstGame = false
end

function MinesweeperClient:gameEnd(victory, extraData)
    local board = self.Board

    self.GameState = GameEnum.GameState.CleanUp
    board.Discovered = extraData.Discovered or self.Board.Discovered
    board.Mines = extraData.Mines or {}

    if victory == true then
        self.Victory = true
        self.UI.createMessage(
            _compose(VICTORY_MESSAGES) .. " (".. ("%.2f"):format(tostring(extraData.TimeTaken)) .. "s)",
            VICTORY_MESSAGE_COLOR
        )
    elseif victory == false then
        board.ExplosionAt = extraData.ExplosionAt
        self.UI.createMessage(
            _compose(FAIL_MESSAGES, {name = extraData.Who.DisplayName}),
            FAIL_MESSAGE_COLOR
        )
    else
        self.UI.createMessage("Something weird happened... Restarting.", Color3.new(0.5, 0.5, 0.5))
    end

    board:render()

    task.wait(5)

    if self.GameState == GameEnum.GameState.CleanUp then
        self.GameState = GameEnum.GameState.GameOver
        board:destroy()
    end

end

-- TODO: evil... find a better way... more customizable way as well?
function MinesweeperClient:bindInput()
    ContextActionService:UnbindAllActions()

    self._state.Scrolls = 0
    local dragCamera, sweeping = false, false
    local flaggingState = nil
    local moveDirX = 0
    local moveDirY = 0

    local function inputHandler(name, state, object)
        local boolState = state == Enum.UserInputState.Begin and true or false
        if boolState then
            if self.GameState == GameEnum.GameState.InProgress and self:isPlaying() then

                if name == "PlaceFlag" then
                    flaggingState = placeFlag(self)
                    self.UI.updateMouseHover(self)
                    Cursor.LocalCursor.Visible = false
                elseif name == "Discover" then
                    sweeping = true
                    sweep(self, nil)
                    Cursor.LocalCursor.Visible = false
                end
                if name:match("^Select") then
                    local add = {
                        Up = Vector2.new(0, -1),
                        Down = Vector2.new(0, 1),
                        Left = Vector2.new(-1, 0),
                        Right = Vector2.new(1, 0)
                    }

                    for key, value in pairs(add) do
                        if name:match(key .. "$") then
                            moveSelection(self, value)
                        end
                    end
                end
                if name:match("^NoMouse") then
                    if name:match("PlaceFlag$") then
                        placeFlag(self, nil, Cursor.LocalCursor:get())
                    end
                    if name:match("Discover") then
                       sweep(self, nil, Cursor.LocalCursor:get())
                    end
                    if name:match("PlaceFlagModifier") then
                        if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                            return Enum.ContextActionResult.Pass
                        end

                        placeFlag(self, nil, Cursor.LocalCursor:get())
                    end
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
        elseif name == "CameraDown" then
            moveDirY = boolState and 1 or moveDirY < 0 and -1 or 0
        elseif name == "CameraUp" then
            moveDirY = boolState and -1 or moveDirY > 0 and 1 or 0
        elseif name == "CameraRight" then
            moveDirX = boolState and 1 or moveDirX < 0 and -1 or 0
        elseif name == "CameraLeft" then
            moveDirX = boolState and -1 or moveDirX > 0 and 1 or 0
        end

    end

    local function inputChangedHandler(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if dragCamera then
                _moveCamera(self, input.Delta)
            end
            if flaggingState ~= nil then
                placeFlag(self, flaggingState)
            end
            if sweeping then
                sweep(self, sweeping)
            end
            self.UI.updateMouseHover()
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
            debug.profilebegin("game-wasd-camera")
            dt = math.min(1, dt)
            if self.Client.Paused then return end
            if not self.Board or not self.Board.getExtents then return end
            _moveCamera(self, Vector2.new(moveDirX * dt * 200, moveDirY * dt * 200))
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
    ContextActionService:BindAction("SelectUp", inputHandler, true, Enum.KeyCode.Up, Enum.KeyCode.K)
    ContextActionService:BindAction("SelectDown", inputHandler, true, Enum.KeyCode.Down, Enum.KeyCode.J)
    ContextActionService:BindAction("SelectLeft", inputHandler, true, Enum.KeyCode.Left, Enum.KeyCode.H)
    ContextActionService:BindAction("SelectRight", inputHandler, true, Enum.KeyCode.Right, Enum.KeyCode.L)
    ContextActionService:BindAction("NoMouseDiscover", inputHandler, true, Enum.KeyCode.Z, Enum.KeyCode.Space)
    ContextActionService:BindAction("NoMousePlaceFlag", inputHandler, true, Enum.KeyCode.X)
    ContextActionService:BindAction("NoMousePlaceFlagModifier", inputHandler, true, Enum.KeyCode.Space)
end

function MinesweeperClient:bind()

    -- runservice binds
    self._binds.Cursor = RunService:BindToRenderStep(
        "CursorsUpdate",
        500,
        function(dt)
            if self.Client.Paused then return end
            if CursorUpdateTimer:tick(dt) then
                self.CursorManager:sendWorldCursor()
            end
            self.CursorManager:update()

            local cursorInfo = self.Gui.InfoBox.CursorInfo
            cursorInfo.Visible = false

            local nearestCursor = self.CursorManager:getNearestCursor()
            if nearestCursor then
                cursorInfo.Visible = true
                cursorInfo.DisplayName.Text = nearestCursor.Owner.DisplayName
                cursorInfo.DisplayName.TextColor3 = nearestCursor.Color
            end

        end
    )

    self._binds.Camera = RunService:BindToRenderStep(
        "CameraUpdate",
        100,
        function(dt)
            if self.Client.Paused then return end

            workspace.CurrentCamera.CameraType = "Scriptable" --idk why i have to force this... roblox!!! yay!!!
            debug.profilebegin("game-camera")
            self.Camera:updateView(dt)
            debug.profileend("game-camera")
        end
    )

    self._binds.Camera = RunService:BindToRenderStep(
        "BoardDisplayUpdates",
        1000,
        function(dt)
            if self.Client.Paused then return end
            if not self.Board then return end
            if self.GameState == GameEnum.GameState.InProgress then
                self.Displays.Timer:update(os.time(os.date("!*t")) - self.Board.StartedAt)
            end
        end
    )
end


-- TODO: handle networking in another file... much like MinesweeperNetworker on server
function MinesweeperClient:route(packet, ...)
    local args = {...}
    if packet == GameEnum.PacketType.SetFlagState then
        local attempts = 1
        while self.Board == nil and attempts < 10 do task.wait(0.5) attempts = attempts + 1 end
        assert(self.Board ~= nil, "board is missing, nowhere to set flag state on")

        local x, y, state, owner = args[1], args[2], args[3], args[4]

        self.Board:setFlag(x, y, state, owner)
        self.Board:render()

        self.Displays.Flags:update(self.Board.MineCount - TableUtils.getSize(self.Board.Flags))

        if owner == Players.LocalPlayer then return end
        playSound(self, shared.Assets.Sounds.Flag)


    elseif packet == GameEnum.PacketType.Discover then
        local owner, boardDiscovered = args[1], args[2]

        self.Board.Discovered = patchNetworkedBoard(self.Board.Discovered, boardDiscovered)
        self.Board:render()

        self.Displays.Flags:update(self.Board.MineCount - TableUtils.getSize(self.Board.Flags))

        if owner == Players.LocalPlayer then return end
        playSound(self, shared.Assets.Sounds.Discover)

    elseif packet == GameEnum.PacketType.GameState then
        local enumID = args[1]
        local stateEnum = GameEnum.GameState(enumID)

        if stateEnum == GameEnum.GameState.GameOver then
            self:gameEnd(args[2], args[3])
            return
        end

        self:gameBegin(args[2])

        if args[2].Adhoc then
            self.Board:render()
            self.Displays.Flags:update(self.Board.MineCount - TableUtils.getSize(self.Board.Flags))
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

    NetworkLib:send(GameEnum.PacketType.Ready)
end
