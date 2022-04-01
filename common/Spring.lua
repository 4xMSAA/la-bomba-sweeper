-- credit: @x_o

local Maid = require(shared.Common.Maid)

local ITERATIONS = 5

local Spring = {}

function Spring.new(mass, force, damping, speed)
    local spring = {
        Target = Vector3.new(),
        Position = Vector3.new(),
        Velocity = Vector3.new(),
        Mass = mass or 5,
        Force = force or 50,
        Damping = damping or 4,
        Speed = speed or 4
    }

    function spring:shove(x, y, z)
        if not x or x == math.huge or x == -math.huge then
            x = 0
        end
        if not y or y == math.huge or y == -math.huge then
            y = 0
        end
        if not z or z == math.huge or z == -math.huge then
            z = 0
        end
        self.Velocity = self.Velocity + Vector3.new(x, y, z)
    end

    function spring:update(dt)
        local scaledDeltaTime = math.min(dt, 1/15) * self.Speed / ITERATIONS

        for i = 1, ITERATIONS do
            local inertia = self.Target - self.Position
            local acceleration = (inertia * self.Force) / self.Mass

            acceleration = acceleration - self.Velocity * self.Damping

            self.Velocity = self.Velocity + acceleration * scaledDeltaTime
            self.Position = self.Position + self.Velocity * scaledDeltaTime
        end

        return self.Position
    end

    Maid.watch(spring)

    return spring
end

return Spring
