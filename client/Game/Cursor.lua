local CURSOR_UPDATE_TICK = _G.TIMERS.CURSOR_UPDATE

local Maid = require(shared.Common.Maid)
local PlayerChatColor = require(shared.Common.PlayerChatColor)

local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera

---a cursor
---@class Cursor
local Cursor = {}
Cursor.__index = Cursor

function Cursor.newLocal()
   local self = Cursor
   self.LocalCursor = {
      Owner = {Player = Players.LocalPlayer, ID = Players.LocalPlayer.UserId, Name = Players.LocalPlayer.Name},
      Local = true,
      HighlightInstance = Instance.new("SelectionBox", _G.Path.FX),
      BoardSelectionPosition = Vector2.new(1, 1),
      Visible = false
   }
   
   function self.LocalCursor:move(board, direction)
      local newX = math.max(1, math.min(math.ceil(self.BoardSelectionPosition.X + direction.X), board.Options.Size.X))
      local newY = math.max(1, math.min(math.ceil(self.BoardSelectionPosition.Y + direction.Y), board.Options.Size.Y))
      
      self.BoardSelectionPosition = Vector2.new(newX, newY)
   end
   
   function self.LocalCursor:get()
      return self.BoardSelectionPosition
   end
   
   function self.LocalCursor:set(xy)
      self.BoardSelectionPosition = xy
   end

   return self.LocalCursor
end

Cursor.newLocal()

function Cursor.new(owner, GuiInstance)
   local self = {

      Owner = owner,
      GuiInstance = GuiInstance,
      WorldPosition = Vector3.new(),
      HighlightInstance = Instance.new("SelectionBox", _G.Path.FX),
      BoardSelectionPosition = Vector2.new(),
      
      Position = Vector2.new(),

      UsingMovementKeys = false,
      Visible = false,
      Color = PlayerChatColor(owner.Name),
      
      _renderPosition = Vector3.new(),
      _lastChange = elapsedTime(),
      _oldWorldPosition = Vector3.new()
   }

   self.GuiInstance.ImageColor3 = self.Color

   setmetatable(self, Cursor)
   Maid.watch(self)

   return self
end

function Cursor:destroy()
   self.HighlightInstance:Destroy()

   if self.Local then return end
   self.GuiInstance:Destroy()
end

function Cursor:setPosition(worldPos)
   if self.Local then error("cannot set position for local cursor", 2) end

   self._lastChange = elapsedTime()
   self._oldWorldPosition = self.WorldPosition
   self.WorldPosition = worldPos

   local newPosition = Camera:WorldToViewportPoint(self.WorldPosition)
   self.Position = Vector2.new(newPosition.X, newPosition.Y)

end

function Cursor:update(board)
   local dt = math.min(1, (elapsedTime() - self._lastChange) / CURSOR_UPDATE_TICK)
   if not self.Local then
      self._renderPosition = self._oldWorldPosition:lerp(self.WorldPosition, dt)

      local translatedPosition, isInView = Camera:WorldToViewportPoint(self._renderPosition)
      self.Visible = isInView

      self.GuiInstance.Position = UDim2.new(0, translatedPosition.X, 0, translatedPosition.Y)

      self.GuiInstance.Visible = false
      self.HighlightInstance.Visible = false

      if self.UsingMovementKeys then
         self.HighlightInstance.Visible = self.Visible
      else
         self.GuiInstance.Visible = self.Visible
      end
   else
      self.HighlightInstance.Visible = self.Visible
   end
end

return Cursor