local CURSOR_THRESHOLD_PX = 50

local UIS = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")

local GameEnum = shared.GameEnum

local Maid = require(shared.Common.Maid)
local NetworkLib = require(shared.Common.NetworkLib)
local Cursor = require(_G.Client.Game.Cursor)
local log, logwarn = require(shared.Common.Log)(script:GetFullName())


---Keeps track of all cursors in the game, having responsibility of networking as well
---@class CursorManager
local CursorManager = {}
CursorManager.__index = CursorManager

function CursorManager.new(game)
    local self = {
        Game = game,
        LocalCursorChanged = false,

        Cursors = {},
        
        _state = {},
        _raycastParams = RaycastParams.new()
    }


    setmetatable(self, CursorManager)
    Maid.watch(self)

    self.Cursors[Players.LocalPlayer.UserId] = Cursor.LocalCursor

    return self
end


function CursorManager:getNearestCursor()
    local mouseLoc = UIS:GetMouseLocation()
    
    for _, cursor in pairs(self.Cursors) do
        if cursor.Visible and (cursor.Position - mouseLoc).magnitude < CURSOR_THRESHOLD_PX then
            return cursor
        end
    end
end

function CursorManager:createNewCursor(owner)
    local cursor = Cursor.new(owner, self.Game.UI.createCursor()) 
    self.Cursors[owner.ID] = cursor
end

function CursorManager:removeCursorByID(id)
    self.Cursors[id]:destroy()
    self.Cursors[id] = nil
end


function CursorManager:sendWorldCursor()
    local mouseLoc = UIS:GetMouseLocation()

    if self._state.CursorLastPosition == mouseLoc or UIS:GetMouseDelta().magnitude > 0.1 then return end
    self._state.CursorLastPosition = mouseLoc

    local cameraRay = Camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
    local worldRay = workspace:Raycast(cameraRay.Origin, cameraRay.Direction * 200)
    if worldRay then
        local position = worldRay.Position

        NetworkLib:send(GameEnum.PacketType.CursorUpdate, "update", position)
    end
end

function CursorManager:sendSelectCursor()
    local board = game.Board
end

function CursorManager:listen()
    NetworkLib:listenFor(GameEnum.PacketType.CursorUpdate, function(status, ...)
        local args = {...}
        if status == "update" then
            local cursors = args[1]
            for ownerID, cursorPosition in pairs(cursors) do
                if self.Cursors[tonumber(ownerID)] then
                    self.Cursors[tonumber(ownerID)]:setPosition(cursorPosition)
                end
            end

            -- self.Game.Board:renderCursors(self:getSelectionCursors())
        elseif status == "add" then

            local owner = args[1]
            if owner.ID == Players.LocalPlayer.UserId then return end

            self:createNewCursor(owner)
            log(2, "received cursor from", owner.ID)
        elseif status == "remove" then
            local id = args[1]
            self:removeCursorByID(tonumber(id))
            log(2, "removing cursor from", id)
        end

    end)
end

function CursorManager:update()
    for _, cursor in pairs(self.Cursors) do
        cursor:update()
    end
end


return CursorManager