--[[
    Events but without the headache of
    "Cannot convert mixed or non-array tables: keys must be strings"
    when working with BindableEvents as signals (looking at stravant's CreateSignal utility)
--]]
local Maid = require(shared.Common.Maid)

local function getSize(t)
    local i = 0
    for _,_ in pairs(t) do
        i = i + 1
    end
    return i
end

local Listener = {}
function Listener.new(emitter, func, eventName, once)
    local self = {}
    self.run = func
    self.emitter = emitter

    function self:close()
        self.emitter.listeners[self] = nil
    end

    self.disconnect = self.close
    self.Disconnect = self.close

    -- listen for a specific scenario
    if eventName then
        self.run = function(...)
            local args = {...}
            if args[1] ~= eventName then return end

            func(unpack(args))

            -- only listen once
            if not once then return end
            self:close()
        end
    end

    for _, data in pairs(self.emitter.eventQueue) do
        func(unpack(data))
    end

    return self
end

---Roblox-style signals
---@class Emitter
local Emitter = {}
function Emitter.new()
    local self = {}
    self.listeners = {}
    self.eventQueue = {}

    -- Used to create the wait method of an emitter without Lua-side magickityjiggitywhatever
    local waitHack = Instance.new("BindableEvent")

    function self:listen(listener)
        if type(listener) ~= "function" then
            error("expected function for argument #1, got " .. type(listener), 2)
        end

        local conn = Listener.new(self, listener)
        self.listeners[conn] = true

        return conn
    end

    function self:on(eventName, listener)
        if type(listener) ~= "function" then
            error("expected function for argument #1, got " .. type(listener), 2)
        end

        local conn = Listener.new(self, listener, eventName)
        self.listeners[conn] = true

        return self, conn
    end

    function self:once(eventName, listener)
        if type(listener) ~= "function" then
            error("expected function for argument #1, got " .. type(listener), 2)
        end

        local conn = Listener.new(self, listener, eventName, true)
        self.listeners[conn] = true

        return self, conn
    end

    function self:closeAll()
        for listener, _ in pairs(self.listeners) do
            listener:close()
        end
    end

    ---Waits until the signal is fired again
    function self:wait()
        return waitHack:Wait()
    end

    function self:emit(...)
        if getSize(self.listeners) == 0 then
            table.insert(self.eventQueue, {...})
        end
        waitHack:Fire()
        for listener, _ in pairs(self.listeners) do
            listener.run(...)
        end
    end

    self.connect = self.listen
    self.Connect = self.listen

    self.Wait = self.wait

    self.fire = self.emit
    self.Fire = self.emit
    self.Emit = self.emit

    Maid.watch(self)

    return self
end

return Emitter
