local Maid = require(shared.Common.Maid)

local SevenSegmentAsset = shared.Assets.SevenSegment
local SevenSegmentConfig = require(shared.Assets.SevenSegmentConfig)

local function updateSegmentDisplay(self, display, num)
    for _, segPart in pairs(display:GetChildren()) do
        if segPart.Name:match("%d+") then
            segPart.Material = self.MaterialOff
            segPart.Color = self.ColorOff
        end
    end
    for _, segment in pairs(SevenSegmentConfig[num]) do
        local segPart = display:FindFirstChild(tostring(segment))
        segPart.Material = self.MaterialOn
        segPart.Color = self.ColorOn
    end
end

---A seven segment display that can be positioned and colored as required
---@class SevenSegment
local SevenSegment = {}
SevenSegment.__index = SevenSegment

function SevenSegment.new(slots)
    assert(typeof(slots) == "number" and slots > 1, "there must be atleast one slot for a display")
    local self = {
        Displays = {},
        CFrame = CFrame.new(),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Enabled = true,

        ColorOn = Color3.new(1, 0, 0),
        ColorOff = Color3.new(0.2, 0, 0),

        MaterialOn = Enum.Material.Neon,
        MaterialOff = Enum.Material.SmoothPlastic
    }
    
    local model = Instance.new("Model")
    model.Name = "SevenSegmentDisplay"
    self.Model = model
    
    self.Model.Parent = _G.Path.FX

    for slot = 0, slots - 1 do
        local display = SevenSegmentAsset:Clone()
        display.Parent = model
        display:SetPrimaryPartCFrame(CFrame.new(slot * display.PrimaryPart.Size.X, 0, 0))
        self.Displays[slot + 1] = display
    end

    setmetatable(self, SevenSegment)
    Maid.watch(self)

    self:update(0)

    return self
end

function SevenSegment:setCFrame(cf)
    self.CFrame = cf
    local extents = self.Model:GetExtentsSize() / 2
    local offset = CFrame.new(-extents.X + (extents.X * self.AnchorPoint.X * 2), 0, -extents.Z + (extents.Z * self.AnchorPoint.Y * 2))
    self.Model:PivotTo(self.CFrame * offset)
end

function SevenSegment:blank()
    for _, display in pairs(self.Displays) do
        for _, segPart in pairs(display:GetChildren()) do
            if segPart.Name:match("%d+") then
                segPart.Material = self.MaterialOff
                segPart.Color = self.ColorOff
            end
        end
    end
end

function SevenSegment:update(num)
    num = math.floor(num)
    self:blank()
    local glyphs = {}
    local negative
    if num < 0 then 
        negative = true
        num = math.abs(num)
    end

    for _ = 1, #self.Displays do
        local remainder = math.floor(num % 10)
        num = num * 0.1
        table.insert(glyphs, 1, remainder)
        
        if num < 1 then
            break
        end
    end
    
    glyphs = negative and table.insert(glyphs, 1, "-") and glyphs or glyphs
    
    self:write(glyphs)
end

function SevenSegment:write(array)
    assert(#array <= #self.Displays, "too many digits to fit")
    for index, glyph in pairs(array) do
        updateSegmentDisplay(self, self.Displays[index + (#self.Displays - #array)], glyph)
    end
        
end
return SevenSegment