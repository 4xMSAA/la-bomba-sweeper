local Maid = require(shared.Common.Maid)
local Behaviours = require(script.Behaviours)

---
---@class Particle
local Particle = {}
Particle.__index = Particle
Particle._behaviours = Behaviours

---@param effect userdata
---@param parent userdata Where to parent the Particle instances to
function Particle.new(effect, parent, props, pooled)
    -- TODO: pool them
    assert(effect, "effect cannot be nil (must be an Instance)")

    local clonedEffect = effect:Clone()
    local self = {
        _HostObject = clonedEffect,

        Parent = parent,
        Instances = clonedEffect:GetChildren(),
        Name = effect:GetFullName(),
        Configuration = require(
            assert(effect:WaitForChild("Configuration"), "no configuration for particle " .. effect:GetFullName())
        ),
        Properties = props or {}
    }

    setmetatable(self, Particle)
    self:_init()
    Maid.watch(self)

    return self
end

function Particle:_init()
    if self.Parent then
        if self.Parent:IsA("BasePart") then
            self._attachment = Instance.new("Attachment")
            self._attachment.Parent = self.Parent
        elseif self.Parent:IsA("BasePart") then
            self._attachment = self.Parent
        end
    elseif self.Properties["UseEffectPart"] == true then
        self._attachment = self._HostObject
    else
        logwarn(1, "particle", self.Name, "has missing parent, started from:", debug.traceback("\n"))
    end

    for _, instance in pairs(self.Instances) do
        if self.Configuration.Colorable and self.Configuration.Colorable[instance.Name] then
            instance.Color = self.Configuration.Colorable[instance.Name].new(self.Properties.Color)
        end

        if instance:IsA("Light") or instance:IsA("ParticleEmitter") then
            instance.Enabled = false
        end

        instance.Parent = self._attachment
    end
end

function Particle:emit()
    for _, child in pairs(self.Instances) do
        if Particle._behaviours[child.ClassName] then
            Particle._behaviours[child.ClassName](child, self.Configuration, self.Properties)
        end
    end

    if self.Configuration.RandomSingleSound then
        local sounds = {}
        for _, sound in pairs(self.Instances) do
            if sound:IsA("Sound") then
                table.insert(sounds, sound)
            end
        end

        if #sounds > 0 then
            sounds[math.random(#sounds)]:Play()
        else
            warn("no sound instances for particle " .. self.Name)
        end
    end
end

return Particle
