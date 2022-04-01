local SmallUtils = {
    ActiveTweens = {}
}

local function lerp(v0, v1, t)
    return (1 - t) * v0 + t * v1
end

SmallUtils.lerp = lerp

function SmallUtils.tweenNumber(obj, property, target, speed, easingFunc)
    if SmallUtils.ActiveTweens[obj] and SmallUtils.ActiveTweens[obj][property] then
        SmallUtils.ActiveTweens[obj][property]:disconnect()
    end

    local initialValue = obj[property]
    local _time = 0
    local tweenProcess
    tweenProcess =
        game:GetService("RunService").Heartbeat:connect(
        function(dt)
            _time = math.min(1, _time + dt * (speed or 1))
            obj[property] = lerp(initialValue, target, easingFunc and easingFunc(_time) or _time)
            if _time >= 1 or obj[property] == target then
                tweenProcess:disconnect()
            end
        end
    )

    if not SmallUtils.ActiveTweens[obj] then
        SmallUtils.ActiveTweens[obj] = {}
    end

    SmallUtils.ActiveTweens[obj][property] = tweenProcess
end

function SmallUtils.rightPad(str, len, char)
    str = tostring(str)
    if char == nil then
        char = " "
    end
    return char:rep(len - str:len()) .. str
end

function SmallUtils.leftPad(str, len, char)
    str = tostring(str)
    if char == nil then
        char = " "
    end
    return str .. char:rep(len - str:len())
end

function SmallUtils.split(str, sep, ignoreNewLine)
    local split = {}
    for w in string.gmatch(str, "[^" .. (ignoreNewLine and sep or "\r\n" .. sep) .. "]+") do
        table.insert(split, w)
    end
    return split
end

function SmallUtils.randomFloatRange(min, max)
    if max < min then
        error("value min (" .. min .. ") cannot exceed max (" .. max ")", 2)
    end
    local diff = max - min
    return min + math.random()*diff
end

function SmallUtils.diffAngularCF(cf0, cf1)
    return (cf0 - cf0.p) * (cf1 - cf1.p):inverse()
end

return SmallUtils
