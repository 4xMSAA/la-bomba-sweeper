local Maid = require(shared.Common.Maid)

---a cursor
---@class Cursor
local Cursor = {}
Cursor.__index = Cursor

function Cursor.new(owner)
   local self = {}
   

   setmetatable(self, Cursor)
   Maid.watch(self)

   return self
end