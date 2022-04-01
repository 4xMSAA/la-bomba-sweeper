local LOG_LEVEL = _G.LOG_LEVEL or 2

--TODO: load GUI if on client

return function(context)
    local function log(level, ...)
        assert(typeof(level) == "number", "log function must have number as first argument (got " .. typeof(level) .. ")")
        if LOG_LEVEL >= level then
            print("[" .. context .. "]:", ...)
        end
    end
    
    local function logwarn(level, ...)
        assert(typeof(level) == "number", "logwarn function must have number as first argument (got " .. typeof(level) .. ")")
        if LOG_LEVEL >= level then
            warn("[" .. context .. "]:", ...)
        end
    end

    return log, logwarn
end