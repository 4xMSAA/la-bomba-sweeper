local CURSOR_UPDATE_TICK = _G.TIMERS.CURSOR_UPDATE

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
      WorldPosition = Vector3.new(),
      
      Position = Vector2.new(),
      Visible = false,
      Color = PlayerChatColor(owner.Name),
      
      _renderPosition = Vector3.new(),
      _lastChange = os.clock(),
      _oldWorldPosition = Vector3.new()
   }

   self.GuiInstance.ImageColor3 = self.Color

   setmetatable(self, Cursor)
   Maid.watch(self)

   return self
end

function Cursor:destroy()
   self.GuiInstance:Destroy()
end

function Cursor:setPosition(worldPos)
   self._lastChange = os.clock()
   self._oldWorldPosition = self.WorldPosition
   self.WorldPosition = worldPos

   local newPosition = Camera:WorldToViewportPoint(self.WorldPosition)
   self.Position = Vector2.new(newPosition)

end

function Cursor:update()
   local dt = math.min(1, (os.clock() - self._lastChange) / CURSOR_UPDATE_TICK)
   self._renderPosition = self._oldWorldPosition:lerp(self.WorldPosition, dt)

   local translatedPosition, isInView = Camera:WorldToViewportPoint(self._renderPosition)
   self.Visible = isInView

   self.GuiInstance.Position = UDim2.new(0, translatedPosition.X, 0, translatedPosition.Y)
   self.GuiInstance.Visible = self.Visible
end

return Cursor