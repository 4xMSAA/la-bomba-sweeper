local TableUtils = require(shared.Common.TableUtils)


-- TODO: branch off of moon animation suite due to how badly exporting
-- is handled, there's already a bunch of code to make that tool work
-- with some exceptions and stuff
local AnimationParser = {}
AnimationParser.CustomPoseProperties = {
    xSIXxCustomDir = function(object)
        return "EasingDirection", object.Value
    end,
    xSIXxCustomStyle = function(object)
        return "EasingStyle", object.Value
    end,
    xSIXxNull = function(object)
        return "Ignore", true
    end
}

---
---@param pose userdata
---@param joints userdata
function AnimationParser.lookupJointByPose(pose, joints)
    -- roblox poses find the right part by the Pose instance's name
    -- on top of that, Part1's name of a joint is linked with the Pose's name
    -- why did roblox do that? no fuckin idea

    for _, joint in pairs(joints) do
        if joint.Part1.Name == pose.Name then
            return joint, pose
        end
    end

    return nil, nil
end

---Map all poses to their respective joint instances
---@param keyframe userdata
---@param model userdata
---@param map function A function that returns key and value for the keyframe and pose provided
function AnimationParser.keyframeToJoints(keyframe, model, map)
    local result = {}

    -- find all joints
    local joints = {}
    for i, joint in pairs(model:GetDescendants()) do
        if joint:IsA("Motor6D") then
            table.insert(joints, joint)
        end
    end

    -- map pose to joint
    local poses = keyframe:GetDescendants()
    for _, pose in pairs(poses) do
        if pose:IsA("Pose") then
            local customProps = {}
            for _, object in pairs(pose:GetChildren()) do
                if AnimationParser.CustomPoseProperties[object.Name] then
                    local prop, value = AnimationParser.CustomPoseProperties[object.Name](object)
                    customProps[prop] = value
                end
            end
            if not customProps.Ignore then
                -- if we have a remap and it has a pose for that joint, 
                -- use that - otherwise get joint in the Animator model
                local joint, mappedPose = (map and map(keyframe, pose)) or AnimationParser.lookupJointByPose(pose, joints)
                pose = mappedPose or pose

                if joint then
                    -- roblox does not support OutIn or Quad, Quart, Quint and other
                    -- styles so the pose must be wrapped behind a table
                    local direction = customProps.EasingDirection or pose.EasingDirection.Name
                    local style = customProps.EasingStyle or pose.EasingStyle.Name

                    -- print(keyframe.Time, pose.Name, style, direction)

                    result[joint] = {
                        Instance = pose,
                        Name = pose.Name,
                        Weight = pose.Weight,
                        CFrame = pose.CFrame,
                        EasingDirection = direction,
                        EasingStyle = style
                    }
                end
            end
        end
    end

    return result
end

---Create a track where keyframes are ordered in an array by Time property
---along with their Pose
---@param keyframeSequence userdata
---@param model userdata
---@param keyframeMap function A function that returns key and value for the keyframe and pose provided
---@return table
function AnimationParser.createTrack(keyframeSequence, model, keyframeMap)
    local track = {}

    -- make all keyframes, but they're unsorted
    for _, keyframe in pairs(keyframeSequence:GetChildren()) do
        if not keyframe:FindFirstChild("xSIXxNull") then
            track[#track + 1] = {
                Time = keyframe.Time,
                Instance = keyframe,
                Poses = AnimationParser.keyframeToJoints(keyframe, model, keyframeMap),
                Markers = keyframe:GetMarkers()
            }
        end
    end

    -- sort them by Time property
    return TableUtils.valueBubblesort(track, "Time")
end

function AnimationParser.getLastKeyframe(keyframeSequence)
    local x, resultKeyframe = 0, nil
    for _, keyframe in pairs(keyframeSequence:GetChildren()) do
        if keyframe.Time >= x then
            x = keyframe.Time
            resultKeyframe = keyframe
        end
    end

    return resultKeyframe, x
end

return AnimationParser
