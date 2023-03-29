local Maid = require(shared.Common.Maid)

local PanelTemplate = shared.Assets.Panel

---A 3D panel in the world to display SurfaceGuis on (style elements in instance)
---@class Panel
local Panel = {}
Panel.__index = Panel

function Panel.new(parent)
    local self = {
        Instance = PanelTemplate:Clone(),

        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = Vector2.new(2, 2),
        CFrame = CFrame.new(),
    }
    
    self.Gui = Instance.WorkingSurface
    
    setmetatable(self, Panel)
    Maid.watch(self)

    self.Instance.Parent = parent

    return self
end

function Panel:setSize(vec2)
    assert(typeof(vec2) == "Vector2", "can only use Vector2 for Panel size")

    self.Size = vec2
    self.Instance.Size = Vector3.new(math.floor(self.Size.X), math.floor(self.Size.Y), 1)
end

function Panel:setSizeWithBorder(vec2)
    assert(typeof(vec2) == "Vector2", "can only use Vector2 for Panel size")

    local pps = self.Instance.EffectsPanel.PixelsPerStud
    local translatedSize = vec2 + Vector2.new(pps * 2, pps * 2)
    self:setSize(translatedSize)
end

function Panel:getBorderSize()
    return self.Instance.EffectsPanel.PixelsPerStud
end

function Panel:setCFrame(cf)
    self.CFrame = cf
    local extents = self.Size / 2
    local offset = CFrame.new(-extents.X + (extents.X * self.AnchorPoint.X * 2), 0, -extents.Y + (extents.Y * self.AnchorPoint.Y * 2))
    self.Instance:PivotTo(self.CFrame * offset)
end

return Panel