local Maid = require(shared.Common.Maid)

---A manually ticked timer where the tick method returns 
---false or the number of times it has ticked past it's cycle
---@class Timer
local Timer = {}
Timer.__index = Timer

function Timer.new(interval)
    local self = {
        Interval = interval,
        _currentTimePassed = 0
    }
    
    setmetatable(self, Timer)
    Maid.watch(self)
    return self
end

function Timer:setInterval(interval)
    self.Interval = interval
end

function Timer:tick(dt)
    self._currentTimePassed = self._currentTimePassed + dt
    if self._currentTimePassed >= self.Interval then
        return math.floor(self._currentTimePassed/self.Interval)
    end
    return false
end

return Timer