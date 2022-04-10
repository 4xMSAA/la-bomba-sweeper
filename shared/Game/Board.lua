local DEFAULT_RENDER_OPTIONS = _G.BOARD.RENDER
local DEFAULT_GENERATE_OPTIONS = _G.BOARD.GENERATION

local Maid = require(shared.Common.Maid)
local GameEnum = shared.GameEnum
local log, logwarn = require(shared.Common.Log)(script:GetFullName())

local function makeTile(x, y)
    return {X = x, Y = y}
end

local function makeFlag(owner, x, y)
    return {
        Owner = owner,
        Model = shared.Assets:WaitForChild("Flag"),
        X = x,
        Y = y
    }
end


---board idk
---@class Board
local Board = {}
Board.__index = Board

function Board.new(options, renderOptions)
    local self = {
        Options = options or DEFAULT_GENERATE_OPTIONS,
        RenderOptions = renderOptions or DEFAULT_RENDER_OPTIONS,
        Discovered = {},
        Flags = {},
        Mines = {},
        
        _render = {}
    }
    
    for x = 1, self.Options.Size.X do
        self.Discovered[x] = {}
        for y = 1, self.Options.Size.Y do
           self.Discovered[x][y] = -1
        end
    end


    setmetatable(self, Board)
    Maid.watch(self)

    return self
end

function Board:generate(options)
    options = options or self.Options

    local totalTiles = (options.Size.X*options.Size.Y)
    local capacity = (totalTiles * (options.MinePercentage / 100))
    
    local available = {}
    for x = 1, options.Size.X do
        for y = 1, options.Size.Y do
            table.insert(available, {X = x, Y = y})
        end
    end

    for _ = 1, capacity do
        local index = math.random(#available)
        local coords = available[index]
        table.remove(available, index)
        table.insert(self.Mines, coords)
    end
end

function Board:getTile(x, y)
    if not x or not y then logwarn(1, "invalid tile to get", "\n", debug.traceback()) return end
    if x < 1 or y < 1 or x > self.Options.Size.X or y > self.Options.Size.Y then return end

    for _, mine in pairs(self.Mines) do
        if mine.X == x and mine.Y == y then
            return "Mine"
        end
    end

    return self.Discovered[x][y]
end

function Board:getNearbyTiles(x, y)
    assert(_G.Server, "only server can get nearby tiles")

    local tiles = {}
    for xOffset = -1, 1 do
        for yOffset = -1, 1 do
            if not (xOffset == 0 and yOffset == 0) then
                local response = self:getTile(x + xOffset, y + yOffset)
                if response then
                    table.insert(tiles, makeTile(x + xOffset, y + yOffset))
                end
            end
        end
    end

    return tiles
end

function Board:getNearbyMinesCount(x, y)
    assert(_G.Server, "only server can get nearby mines")
    assert(self:getTile(x, y) ~= "Mine", "cannot get nearby mines on a mine")

    local total = 0
    for xOffset = -1, 1 do
        for yOffset = -1, 1 do
            local response = self:getTile(x + xOffset, y + yOffset)
            if response == "Mine" then
                total = total + 1
            end
        end
    end

    return total
end

function Board:mouseToBoard(pos)
    local x, y = pos.X, pos.Z

    local offsetX = self.RenderOptions.Size.X * (self.Options.Size.X / 2) + self.RenderOptions.Size.X
    local offsetY = self.RenderOptions.Size.Z * (self.Options.Size.Y / 2) + self.RenderOptions.Size.X
    
    local transformedX = math.floor((x + offsetX) / (self.RenderOptions.Size.X))
    local transformedY = math.floor((y + offsetY) / (self.RenderOptions.Size.Z))

    return 
        transformedX > 0 and transformedY > 0 
        and transformedX <= self.Options.Size.X and transformedY <= self.Options.Size.Y 
        and {X = transformedX, Y = transformedY}
        or nil
end

function Board:isFlagged(x, y)
    for _, flag in pairs(self.Flags) do
        if flag.X == x and flag.Y == y then
            return true
        end
    end

    return false
end

function Board:setFlag(x, y, state, owner)
    local tile = self:getTile(x, y)
    if tile == -1 and state then
        table.insert(self.Flags, makeFlag(owner, x, y))
    elseif tile and not state then
        if _G.Client then
            -- i hate this
            for flagR, part in pairs(self._render.flags) do
                if flagR.X == x and flagR.Y == y then
                    part:Destroy()
                    self._render.flags[flagR] = nil
                end
            end
        end
        for i, flag in pairs(self.Flags) do
            if flag.X == x and flag.Y == y then
                self.Flags[i] = nil
            end
        end
    end
end

function Board:discover(startX, startY)
    assert(_G.Server, "only server can discover the board")

    local tile = self:getTile(startX, startY)

    if tile == "Mine" then
        return GameEnum.Discovery.Mine
    elseif tile == -1 then
        local exploreTiles = {makeTile(startX, startY)}

        while #exploreTiles > 0 do
            local exploreTile = exploreTiles[1]
            local x, y = exploreTile.X, exploreTile.Y
            table.remove(exploreTiles, 1)

            if self:getTile(x, y) == -1 then
                local nearbyMines = self:getNearbyMinesCount(x, y)
                self.Discovered[x][y] = nearbyMines
                if self:isFlagged(x, y) then self:setFlag(x, y, false) end

                if nearbyMines == 0 then
                    for _, newTile in pairs(self:getNearbyTiles(x, y)) do
                        if self:getTile(newTile.X, newTile.Y) == -1 then
                            table.insert(exploreTiles, newTile) 
                        end
                    end
                end
            end
        end

        return GameEnum.Discovery.Safe
    end

    return GameEnum.Discovery.Ignore
end

function Board:serialize(noMines)
    return {
        Options = self.Options,
        Discovered = self.Discovered,
        Flags = self.Flags,
        Mines = noMines and nil or self.Mines,
    }
end

function Board:renderCreate(renderOptions)
    assert(_G.Client, "only client can render the board")

    if self._render.model then
        for _, part in pairs(self._render.parts) do
            part:Destroy()
        end
        self._render.model:Destroy()
    end

    self._render.parts = {}
    self._render.flags = {}
    self._render.model = Instance.new("Model")
    renderOptions = renderOptions or self.RenderOptions
    local genOptions = self.Options
    local CFoffset = CFrame.new(
        -genOptions.Size.X / 2 * renderOptions.Size.X + renderOptions.Size.X/2,
        0,
        -genOptions.Size.Y / 2 * renderOptions.Size.Z + renderOptions.Size.Z/2
    ) * CFrame.new(renderOptions.Pivot)

    for x = 0, genOptions.Size.X - 1 do
        self._render.parts[x + 1] = {}
        for y = 0, genOptions.Size.Y - 1 do
            local p = shared.Assets:WaitForChild("GridPart"):Clone()
            p.Material = Enum.Material.SmoothPlastic
            p.Size = renderOptions.Size
            p.CFrame = CFoffset * CFrame.new(x * renderOptions.Size.X, 0, y * renderOptions.Size.Z) * CFrame.Angles(0, -math.pi/2, 0)
            p.Parent = self._render.model
            

            self._render.parts[x + 1][y + 1] = {
                Color = p.Color,
                Size = p.Size,
                CFrame = p.CFrame,
                Instance = p,
                Label = p:WaitForChild("SurfaceGui"):WaitForChild("Label")
            }
        end
    end
end

function Board:getRenderModel()
    return self._render.model
end

function Board:render(renderOptions)
    assert(_G.Client, "only client can render the board")

    renderOptions = renderOptions or self.RenderOptions

    if not self._render.model then
        self:renderCreate(renderOptions)
    end
    self._render.model.Parent = _G.Workspace

    for x, xTable in pairs(self._render.parts) do
        for y, part in pairs(xTable) do
            local i = ((x - 1) * self.Options.Size.Y) + y
            local offset = x % 2
            local useSecondary = y + offset % 2
            local number = self.Discovered[x][y]
            part.Label.Text = number > 0 and number or ""
            part.Label.TextColor3 = number > 0 and renderOptions.TextColor[number] or Color3.new()
            part.Instance.Color = 
                (self.ExplosionAt and self.ExplosionAt.X == x and self.ExplosionAt.Y == y) and renderOptions.PartColor.MineClicked or
                self:getTile(x, y) == "Mine" and renderOptions.PartColor.Mine or
                number > 0 and renderOptions.PartColor.DiscoveredNearby or 
                number == 0 and renderOptions.PartColor.DiscoveredZero or 
                useSecondary % 2 == 0 and renderOptions.PartColor.Primary or renderOptions.PartColor.Secondary
        end
    end
    
    -- clear any flags placed if they are discovered
    for _, flag in pairs(self.Flags) do
        local x, y = flag.X, flag.Y
        if self:getTile(x, y) ~= -1 then
            self:setFlag(x, y, false)
        end
    end
    
    for i, flag in pairs(self.Flags) do
        local x, y = flag.X, flag.Y
        local flagPart = self._render.flags[flag] or flag.Model:Clone()
        local part = self._render.parts[x][y]
        self._render.flags[flag] = flagPart

        flagPart.Parent = part.Instance
        flagPart:SetPrimaryPartCFrame(part.CFrame * CFrame.new(0, part.Size.Y/2, 0))
    end
end

function Board:postProcess(renderOptions)

end

function Board:destroy()
    print(self, "hi???")
    if _G.Client then
        for _, flagPart in pairs(self._render.flags) do
            flagPart:Destroy()
        end
        if self._render.model then
            self._render.model:Destroy()
        end
    end
end

return Board