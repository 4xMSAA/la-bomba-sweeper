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
      GuiInstance = GuiInstance
   }

   self.GuiInstance.ImageColor3 = PlayerChatColor(owner.Name)

   setmetatable(self, Cursor)
   Maid.watch(self)

   return self
end

function Cursor:destroy()
   self.GuiInstance:Destroy()
end

function Cursor:setPosition(worldPoint)
   local newPosition, isInView = Camera:WorldToViewportPoint(worldPoint)
   self.GuiInstance.Position = UDim2.new(0, newPosition.X, 0, newPosition.Y)
   self.GuiInstance.Visible = isInView
end

return Cursor