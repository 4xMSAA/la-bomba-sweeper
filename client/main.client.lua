_G.Client = script.Parent

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
require(ReplicatedStorage.Source:WaitForChild("InitializeEnvironment"))

local GameEnum = shared.GameEnum

local NetworkLib = require(shared.Common.NetworkLib)
local Maid = require(shared.Common.Maid)
local Timer = require(shared.Common.Timer)

local Camera = require(_G.Client.Core.Camera).new(workspace.CurrentCamera)

local debugPause = false

-- TODO: actual input binding
local function init(character)

    -- temporary input binding
    local function inputHandler(name, state, object)
        local boolState = state == Enum.UserInputState.Begin and true or false
        if name == "debugPause" and boolState then
            debugPause = not debugPause
        elseif name == "debugLog" and boolState then
            Maid.info()
        end
    end

    local function inputChangedHandler(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            Camera:moveLook(input.Delta.x, input.Delta.y)
        end
    end

    ContextActionService:BindAction("debugPause", inputHandler, true, Enum.KeyCode.P)
    ContextActionService:BindAction("debugLog", inputHandler, true, Enum.KeyCode.O)

    UserInputService.InputChanged:connect(inputChangedHandler)
end

-- network binds
local function route(packetType, ...)
    ClientGame:route(packetType, ...)
end

NetworkLib:listen(route)

-- runservice binds
RunService:BindToRenderStep(
    "CursorsUpdate",
    500,
    function(dt)
        if debugPause then
            return
        end

    end
)

RunService:BindToRenderStep(
    "CameraUpdate",
    100,
    function(dt)
        debug.profilebegin("game-camera")
        Camera:updateView(dt)
        debug.profileend("game-camera")
    end
)

RunService.Heartbeat:connect(function(dt)
    if debugPause then
        return
    end
end)
