--[[
    Hassle with Roblox characters being loaded is very unknown and stupid
    Module aims to simplify use of character with custom camera setups
--]]
local Emitter = require(shared.Common.Emitter)

local LocalCharacter = {
    Player = nil,
    Controller = nil,
    Velocity = 0,
    CharacterTransparency = 1,
    CameraUpdated = Emitter.new(),
    StoredState = {}
}

---Helper function to set object transparency
---@param object userdata
---@param value number
local function setObjectTransparency(object, value, originalStateTable)
    if object:IsA("BasePart") then
        object.LocalTransparencyModifier = value
    end

    if object:IsA("ParticleEmitter") then
        if not originalStateTable[object] then
            originalStateTable[object] = object.Enabled
        end
        object.Enabled = value >= 1 and false or originalStateTable[object]
    end
end

---Returns the character currently as the player's character
---@return userdata LocalPlayer's character
function LocalCharacter.get()
    return LocalCharacter.Character
end

---Sets a character model to be the active character to manage
---@param character userdata The LocalCharacter model of a Player to manage
function LocalCharacter.set(character)
    if not character then
        return
    end

    LocalCharacter.Character = character
    character.DescendantAdded:connect(
        function(object)
            LocalCharacter.setTransparency(LocalCharacter.CharacterTransparency, object)
        end
    )
    LocalCharacter.setTransparency(LocalCharacter.CharacterTransparency)
end

---Sets the active character's transparency to the specified value, optionally using an exclusion list
---@param value number Target transparency for the character
---@param target userdata Specify a part to change - default iterates through character
function LocalCharacter.setTransparency(value, target)
    LocalCharacter.CharacterTransparency = value
    if not target and LocalCharacter.Character then
        for _, object in pairs(LocalCharacter.Character:GetDescendants()) do
            setObjectTransparency(object, value)
        end
    elseif target then
        setObjectTransparency(target, value)
    end
end

function LocalCharacter.listenPlayer(player)
    LocalCharacter.Player = player
    player.CharacterAdded:connect(
        function(char)
            LocalCharacter.set(char)
        end
    )
    if player.Character then
        LocalCharacter.set(player.Character)
    end
end

return LocalCharacter
