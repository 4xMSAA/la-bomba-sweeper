--[[
    A camera intended to simplify the process for FPS games
    Has a dynamic weight system
]]
local Emitter = require(shared.Common.Emitter)
local TableUtils = require(shared.Common.TableUtils)

---Calculates an array with [weight] based on a {weight = data} list
---It is important not to use the same weight
---@param list table The list of weights
local function calculateSortedOffsetsArray(list)
    local array = {}
    for weight, data in pairs(list) do
        table.insert(array, weight)
    end

    return TableUtils.valueBubblesort(array)
end

local Camera = {}

---Create a new Camera class which can be controlled
---@param instance userdata Roblox Camera instance to hook to
function Camera.new(instance)
    local self = {
        User = {
            LookPitch = 0,
            LookYaw = 0,
            LimitYaw = math.rad(_G.CAMERA.LIMIT_YAW)
        },
        Instance = instance,
        CFrame = CFrame.new(),
        AttachTo = nil,
        Offsets = {},
        OnUpdating = Emitter.new(),
        OnUpdated = Emitter.new(),
        Zoom = 1,
        FieldOfView = 70,
        LastFrameDelta = 1 / 60,
        _internal = {
            SortedOffsets = {}
        }
    }

    setmetatable(self, {__index = Camera})

    return self
end

---Update the camera view
---@param dt number Delta time how long it took since last RenderStepped frame
function Camera:updateView(dt)
    self.OnUpdating:emit(dt)
    self.Instance.CameraType = "Scriptable"

    -- Update the CFrame of camera
    self.CFrame = self.AttachTo and self:getAttachedCFrame() * self:getUserLook() or self.CFrame

    local finalCFrame = self.CFrame
    for _, cfOffsetIndex in pairs(self._internal.SortedOffsets) do
        local data = self.Offsets[cfOffsetIndex]
        finalCFrame = finalCFrame * data.CFrame

        if (data.include) then
            self.CFrame = self.CFrame * data.CFrame
        end
    end

    self.Instance.CFrame = finalCFrame
    self.LastFrameDelta = dt or (1 / 60)

    self.Instance.FieldOfView = self.FieldOfView / self.Zoom

    self.OnUpdated:emit(self.LastFrameDelta)
end

function Camera:setZoom(modifier)
    self.Zoom = modifier 
end

---a TODO method
---@param cf1 userdata
---@param cf2 userdata
---@param time number
---@param easingFunction function
function Camera:interpolate(cf1, cf2, time, easingFunction)
    -- TODO: Interpolation
end

---Set CFrame of camera
---@param cf userdata Set the camera CFrame
function Camera:setCFrame(cf)
    self.CFrame = cf
    self:setUserLook(cf.lookVector)
end

---Returns the base CFrame, unaffected by camera Offsets
function Camera:getCFrame()
    return self.CFrame
end

---Returns the absolute CFrame, along with Offsets on it
function Camera:getAbsoluteCFrame()
    return self.Instance.CFrame
end

---Add an offset CFrame that won't affect the base CFrame
---@param weight number The order of the CFrame in offset operations
---@param cf userdata CFrame the offset should reflect
---@param affectBaseCFrame boolean
function Camera:addOffset(weight, cf, affectBaseCFrame)
    assert(typeof(weight) == "number", "weight must be a numeric value")
    self.Offsets[weight] = {CFrame = cf, include = affectBaseCFrame}

    -- Refresh the Offsets array
    self._internal.SortedOffsets = calculateSortedOffsetsArray(self.Offsets)
end

---Update an offset - this saves performance as adding an offset performs a sort update.
---@param weight number The order of the CFrame in offset operations
---@param cf userdata CFrame the offset should reflect
---@param affectBaseCFrame boolean Whether it should move the real CFrame too
function Camera:updateOffset(weight, cf, affectBaseCFrame)
    assert(typeof(weight) == "number", "weight must be a numeric value")
    assert(self.Offsets[weight], "offset with weight " .. weight .. " does not exist")

    local data = self.Offsets[weight]
    data.CFrame = cf ~= nil and cf or data.CFrame
    data.include = affectBaseCFrame ~= nil and affectBaseCFrame or data.include
end

---Set the look vector of User's look euler angles
---@param lookVector userdata Vector3 towards the direction for the User to look at
function Camera:setUserLook(lookVector)
    local horizontalLook = lookVector * Vector3.new(1, 0, 1)
    self.User.LookPitch = math.atan2(horizontalLook.x, horizontalLook.z)
    self.User.LookYaw = math.atan2(lookVector.y, horizontalLook.magnitude)
end

---Returns the User look in a CFrame
function Camera:getUserLook()
    return CFrame.fromEulerAnglesYXZ(self.User.LookYaw, self.User.LookPitch, 0)
end

---Translates delta X and Y into the User's look direction and updates the camera
---@param deltaX number Move camera by mouse X delta
---@param deltaY number Move camera by mouse Y delta
function Camera:moveLook(deltaX, deltaY)
    -- something magical about this that i don't remember, but it makes sensitivity behave similar to roblox's
    local frameModifier = math.max(1 / 60, math.min(1 / 45, self.LastFrameDelta)) * 20
    local dX, dY = math.rad(-deltaX) / self.Zoom * frameModifier, math.rad(-deltaY) / self.Zoom * frameModifier

    -- Limit the pitch to only be 360 degrees and yaw to the configured limit
    self.User.LookPitch = (self.User.LookPitch + dX) % (math.pi * 2)
    self.User.LookYaw = math.max(-self.User.LimitYaw, math.min(self.User.LimitYaw, self.User.LookYaw + dY))
end

---Translates delta X and Y into the User's look direction and updates without
---doing input manipulation for preciser movement
---@param deltaX number Move camera by X
---@param deltaY number Move camera by Y
function Camera:rawMoveLook(deltaX, deltaY)
    local dX, dY = math.rad(deltaX) / self.Zoom, math.rad(deltaY) / self.Zoom

    -- Limit the pitch to only be 360 degrees
    self.User.LookPitch = (self.User.LookPitch + dX) % (math.pi * 2)
    -- Limit the yaw
    self.User.LookYaw = math.max(-self.User.LimitYaw, math.min(self.User.LimitYaw, self.User.LookYaw + dY))
end

---Get the CFrame of the camera's AttachTo object
---@param attachObject userdata If provided, will use the attachObject
---                             as the pivot point instead
function Camera:getAttachedCFrame(attachObject)
    local object = attachObject or self.AttachTo
    if (object and object:IsDescendantOf(game)) then
        if (object:IsA("BasePart")) then
            return CFrame.new(object.Position)
        elseif (object:IsA("Humanoid") and object.Parent and object.Parent:FindFirstChild("HumanoidRootPart")) then
            return CFrame.new(object.Parent:FindFirstChild("HumanoidRootPart").Position) *
                CFrame.new(0, object.HipHeight - object.Parent:FindFirstChild("Head").Size.Y / 2, 0) *
                CFrame.new(object.CameraOffset)
        end
    end

    return CFrame.new()
end

return Camera
