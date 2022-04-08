_G.Client = script.Parent

local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage.Source:WaitForChild("InitializeEnvironment"))

local Maid = require(shared.Common.Maid)


---Client instance hosting a bunch of things...
---@class Client
local Client = {}
Client.__index = Client

function Client.new()
    local self = {
        Paused = false
    }

    setmetatable(self, Client)
    Maid.watch(self)

    return self
end

function Client:start(module, options)
    self._running = require(module)(self, options)

    return self
end

local client = Client.new()
client:start(_G.Client.Game.MinesweeperClient)

-- -- TODO: actual input binding
-- local function init(character)

--     -- temporary input binding
--     local function inputHandler(name, state, object)
--         local boolState = state == Enum.UserInputState.Begin and true or false
--         if name == "debugPause" and boolState then
--             debugPause = not debugPause
--         elseif name == "debugLog" and boolState then
--             Maid.info()
--         end
--     end

--     local function inputChangedHandler(input)
--         if input.UserInputType == Enum.UserInputType.MouseMovement then
--             Camera:moveLook(input.Delta.x, input.Delta.y)
--         end
--     end

--     ContextActionService:BindAction("debugPause", inputHandler, true, Enum.KeyCode.P)
--     ContextActionService:BindAction("debugLog", inputHandler, true, Enum.KeyCode.O)

--     UserInputService.InputChanged:connect(inputChangedHandler)
-- end

-- -- network binds
-- local function route(packetType, ...)
--     ClientGame:route(packetType, ...)
-- end

-- NetworkLib:listen(route)

-- -- runservice binds
-- RunService:BindToRenderStep(
--     "CursorsUpdate",
--     500,
--     function(dt)
--         if debugPause then
--             return
--         end

--     end
-- )


-- RunService.Heartbeat:connect(function(dt)
--     if debugPause then
--         return
--     end
-- end)
