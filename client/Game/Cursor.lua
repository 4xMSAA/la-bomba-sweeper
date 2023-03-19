local Maid = require(shared.Common.Maid)
local PlayerChatColor = require(shared.Common.PlayerChatColor)

local Camera = workspace.CurrentCamera

---a cursor
---@class Cursor
local Cursor = {}
Cursor.__index = Cursor

function Cursor.new(owner, GuiInstance)
   local self = {
      Owner = owner,
      GuiInstance = GuiInstance,
      WorldPoint = Vector3.new(),
      
      Position = Vector2.new(),
      Visible = false,
      Color = PlayerChatColor(owner.Name)
   }

   self.GuiInstance.ImageColor3 = self.Color

   setmetatable(self, Cursor)
   Maid.watch(self)

   return self
end

function Cursor:destroy()
   self.GuiInstance:Destroy()
end

function Cursor:setPosition(worldPoint, update)
   self.WorldPoint = not update and worldPoint or self.WorldPoint
   local newPosition, isInView = Camera:WorldToViewportPoint(self.WorldPoint)
   self.Position = newPosition
   self.Visible = isInView
   self.GuiInstance.Position = UDim2.new(0, newPosition.X, 0, newPosition.Y)
   self.GuiInstance.Visible = self.Visible
end

return Cursor