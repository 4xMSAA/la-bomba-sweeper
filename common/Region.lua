local Maid = require(shared.Common.Maid)

---@class Region
local Region = {}

---@param pos userdata
---@param size userdata
function Region.new(pos, size)
    local self = {}
    self.Position = pos or Vector3.new()
    self.Size = size or Vector3.new()
    setmetatable(self, Region)

    Maid.watch(self)

    return self
end

---https://gist.github.com/zeux/1a67e8930df782d5474276e218831e22
---@param model userdata
local function getObjectBoundingBox(model)
    local abs = math.abs
    local inf = math.huge

    local minx, miny, minz = inf, inf, inf
    local maxx, maxy, maxz = -inf, -inf, -inf

    for _, obj in pairs(model:GetDescendants()) do -- model:GetDescendants has to marshal an array of instances to Lua which is pretty expensive but there's no way around it
        if obj:IsA("BasePart") then -- this uses Roblox __namecall optimization - no point caching IsA, it's fast enough (although does involve LuaBridge invocation)
            local cf = obj.CFrame -- this causes a LuaBridge invocation + heap allocation to create CFrame object - expensive! - but no way around it. we need the cframe
            local size = obj.Size -- this causes a LuaBridge invocation + heap allocation to create Vector3 object - expensive! - but no way around it
            local sx, sy, sz = size.X, size.Y, size.Z -- this causes 3 Lua->C++ invocations

            local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cf:components() -- this causes 1 Lua->C++ invocations and gets all components of cframe in one go, with no allocations

            -- https://zeuxcg.org/2010/10/17/aabb-from-obb-with-component-wise-abs/
            local wsx = 0.5 * (abs(R00) * sx + abs(R01) * sy + abs(R02) * sz) -- this requires 3 Lua->C++ invocations to call abs, but no hash lookups since we cached abs value above; otherwise this is just a bunch of local ops
            local wsy = 0.5 * (abs(R10) * sx + abs(R11) * sy + abs(R12) * sz) -- same
            local wsz = 0.5 * (abs(R20) * sx + abs(R21) * sy + abs(R22) * sz) -- same

            -- just a bunch of local ops
            if minx > x - wsx then
                minx = x - wsx
            end
            if miny > y - wsy then
                miny = y - wsy
            end
            if minz > z - wsz then
                minz = z - wsz
            end

            if maxx < x + wsx then
                maxx = x + wsx
            end
            if maxy < y + wsy then
                maxy = y + wsy
            end
            if maxz < z + wsz then
                maxz = z + wsz
            end
        end
    end

    local size = Vector3.new(maxx - minx, maxy - miny, maxz - minz)
    local pos = Vector3.new(minx + size.X / 2, miny + size.Y / 2, minz + size.Z / 2)
    return pos, size
end

---
function Region.fromBoundingBox(model)
    local pos, size = getObjectBoundingBox(model)
    return Region.new(pos, size)
end

---
function Region:updateFromModel(model)
    local pos, size = getObjectBoundingBox(model)
    self.Position = pos
    self.Size = size
end

---
function Region:intersectsWith(target, errorRange, ignoreX, ignoreY, ignoreZ)
    errorRange = errorRange or 0
    local sizePos = self.Position + self.Size / 2
    local uSizePos = self.Position - self.Size / 2

    local sizePosTarget = target.Position + target.Size / 2
    local uSizePosTarget = target.Position - target.Size / 2

    local top, bottom = sizePos.Y, uSizePos.Y
    local left, right = uSizePos.X, sizePos.X
    local front, back = uSizePos.Z, sizePos.Z

    local topTarget, bottomTarget = sizePosTarget.Y, uSizePosTarget.Y
    local leftTarget, rightTarget = uSizePosTarget.X, sizePosTarget.X
    local frontTarget, backTarget = uSizePosTarget.Z, sizePosTarget.Z

    local isInX =
        not ignoreX and (left < rightTarget - errorRange and right - errorRange > leftTarget) or
        ignoreX and true or
        false
    local isInY =
        not ignoreY and (bottom < topTarget - errorRange and top - errorRange > bottomTarget) or
        ignoreY and true or
        false
    local isInZ =
        not ignoreZ and (front < backTarget - errorRange and back - errorRange > frontTarget) or
        ignoreZ and true or
        false

    return isInX and isInY and isInZ
end

function Region:_display()
    if not self._displayPart then
        local p = Instance.new("Part")
        p.Anchored = true
        p.CastShadow = false
        p.Transparency = 0.7
        p.Material = "Neon"
        p.BrickColor = BrickColor.Random()
        self._displayPart = p
    end
    self._displayPart.Size = self.Size
    self._displayPart.CFrame = CFrame.new(self.Position)
    self._displayPart.Parent = workspace
end

function Region:_displayBoundingBox(color)
    if not self._displayPart then
        return
    end
    local bBox = self._displayPart:FindFirstChild("SelectionBox") or Instance.new("SelectionBox")
    bBox.LineThickness = 0.05
    bBox.SurfaceTransparency = 1
    bBox.Adornee = self._displayPart
    bBox.Parent = self._displayPart
    bBox.Color3 = color
    bBox.Transparency = color and 0.5 or 1
end

return Region
