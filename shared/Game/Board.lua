local DEFAULT_RENDER_OPTIONS = _G.BOARD.RENDER
local DEFAULT_GENERATE_OPTIONS = _G.BOARD.GENERATION

local Maid = require(shared.Common.Maid)


---board idk
---@class Board
local Board = {}
Board.__index = Board

function Board.new(options, renderOptions)
    options = options or DEFAULT_GENERATE_OPTIONS

    local self = {
        Options = options,
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

    local capacity = options.MineCount/(options.Size.X*options.Size.Y)
    
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
    if x < 1 or y < 1 or x > self.Options.Size.X or y > self.Options.Size.Y then return end

    for _, mine in pairs(self.Mines) do
        if mine.X == x and mine.Y == y then
            return "Mine"
        end
    end

    return self.Discovered[x][y]
end

local function makeTile(id, x, y)
    return {X = x, Y = y, ID = id}
end

function Board:getNearbyTiles(x, y)
    assert(_G.Server, "only server can get nearby tiles")

    local tiles = {}
    for xOffset = -1, 1, 2 do
        local response = self:getTile(x + xOffset, y)
        if response and response ~= "Mine" then
            table.insert(tiles, makeTile(response, x + xOffset, y + yOffset))
        end
    end
    for yOffset = -1, 1, 2 do
        local response = self:getTile(x, y + yOffset)
        if response and response ~= "Mine" then
            table.insert(tiles, makeTile(response, x + xOffset, y + yOffset))
        end
    end

    return tiles
end

function Board:getNearbyMinesCount(x, y)
    assert(_G.Server, "only server can get nearby mines")
    assert(self:getTile(x, y) == "Mine", "cannot get nearby mines on a mine")

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

function Board:discover(startX, startY)
    assert(_G.Server, "only server can discover the board")

    local tile = self:getTile(startX, startY)

    if tile == "Mine" then
        return GameEnum.Discovery.Mine
    elseif tile == -1 then
        local exploreTiles = {makeTile(tile, startX, startY)}

        while #exploreTiles > 0 do
            local exploreTile = exploreTiles[1]
            local x, y = exploreTile.X, exploreTile.Y
            table.remove(exploreTiles, 1)

            if exploreTile.ID == -1 then
                self.Discovered[x][y] = self:getNearbyMinesCount(x, y)

                for _, newTile in pairs(self:getNearbyTiles(x, y)) do
                    if newTile.ID == -1 then
                        table.insert(exploreTiles, newTile) 
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
    self._render.model = Instance.new("Model")
    renderOptions = renderOptions or self.RenderOptions
    local genOptions = self.Options
    local CFoffset = CFrame.new(
        -genOptions.Size.X / 2 * renderOptions.Size.X / 2,
        0,
        -genOptions.Size.Z / 2 * renderOptions.Size.Z / 2
    ) * CFrame.new(renderOptions.Pivot)

    for x = 0, genOptions.Size.X - 1 do
        self._render.parts[x] = {}
        for y = 0, genOptions.Size.Y - 1 do
            local p = shared.Assets.GridPart
            p.Material = Enum.Material.SmoothPlastic
            p.Size = renderOptions.Size
            p.CFrame = CFoffset * CFrame.new(x, 0, y)
            p.Parent = self._render.model
            

            self._render.parts[x][y] = {
                Color = p.Color,
                Size = p.Size,
                Location = p.CFrame,
                Instance = p,
                Label = p:WaitForChild("SurfaceGui"):WaitForChild("TextLabel")
            }
        end
    end
end

function Board:getRenderModel()
    return self._render.model
end

function Board:render(renderOptions)
    renderOptions = renderOptions or self.RenderOptions

    if not self._render.model then
        self:renderCreate(renderOptions)
    end
    self._render.model.Parent = _G.Workspace

    for x, xTable in pairs(self._render.parts) do
        for y, part in pairs(xTable) do
            local i = x*y + 1 
            local number = self.Discovered[x][y]
            part.Label.Text = number > 0 and number or ""
            part.Instance.Color = 
                number > 0 and renderOptions.PartColor.DiscoveredNearboy or 
                number == 0 and renderOptions.PartColor.DiscoveredZero or 
                i % 2 == 0 and renderOptions.PartColor.Primary or renderOptions.PartColor.Secondary
        end
    end
    
end

function Board:postProcess(renderOptions)

end

return Board