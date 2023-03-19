local UIS = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local GameEnum = shared.GameEnum

local Maid = require(shared.Common.Maid)
local NetworkLib = require(shared.Common.NetworkLib)
local Cursor = require(_G.Client.Game.Cursor)

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

    return self
end


function CursorManager:getNearestCursor()
        
end

function CursorManager:createNewCursor(owner)
    local cursor = Cursor.new(owner, self.Game.UI.createCursor()) 
    self.Cursors[owner.ID] = cursor
end

function CursorManager:removeCursorByID(id)
    self.Cursors[id]:Destroy()
end


function CursorManager:sendWorldCursor()
    if self._state.CursorLastPosition == UserInputService:GetMouseLocation() then return end
    self._state.CursorLastPosition = UserInputService:GetMouseLocation()

    local mouseLoc = UIS:GetMouseLocation()
    local cameraRay = Camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
    local worldRay = workspace:Raycast(cameraRay.Origin, cameraRay.Direction * self.Game._state.CameraHeight * 1.5)
    local position = worldRay.Position
    print(position)

    NetworkLib:send(GameEnum.PacketType.CursorUpdate, "update", position)
end

function CursorManager:listen()
    NetworkLib:listenFor(GameEnum.PacketType.CursorUpdate, function(status, ...)
        local args = {...}
        print("listening for CursorUpdate...", status, args)
        if status == "update" then
            local cursors = args[1]
            for owner, cursorPosition in pairs(cursors) do
                if self.Cursors[owner.ID] then
                    self.Cursors[owner.ID]:setPosition(cursorPosition)
                end
            end
        elseif status == "add" then
            print("create cursor")
            local owner = args[1]
            self:createNewCursor(owner)
        elseif status == "remove" then
            local id = args[1]
            self:removeCursorByID(id)
        end
    end)
end

return CursorManager