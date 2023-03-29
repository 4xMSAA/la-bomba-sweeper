local DEFAULT_RENDER_OPTIONS = _G.BOARD.RENDER
local DEFAULT_GENERATE_OPTIONS = _G.BOARD.GENERATION
local FLAG_OTHER_COOLDOWN = _G.FLAGGING.FLAG_PLACED_OTHER_COOLDOWN
local FLAG_DEFAULT_COLOR = DEFAULT_RENDER_OPTIONS.FLAG_COLOR

local BOARD_UNDISCOVERED = -1
local BOARD_PENDING = -2

local Players = game:GetService("Players")

local Maid = require(shared.Common.Maid)
local PlayerChatColor = require(shared.Common.PlayerChatColor)
local GameEnum = shared.GameEnum
local log, logwarn = require(shared.Common.Log)(script:GetFullName())

local function makeTile(x, y)
    return {X = x, Y = y}
end

local function makeFlag(owner, x, y)
    return {
        PlacedAt = time(),
        Owner = owner,
        Model = shared.Assets:WaitForChild("Flag"),
        X = x,
        Y = y
    }
end

local function colorContents(item, color)
    for _, child in pairs(item:GetDescendants()) do
        if child:IsA("BasePart") and child:GetAttribute("Colorable") then
            child.Color = color
        end
    end
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
        MineCount = 0,
        StartedAt = os.time(os.date("!*t")),
        
        _render = {}
    }
    
    for x = 1, self.Options.Size.X do
        self.Discovered[x] = {}
        for y = 1, self.Options.Size.Y do
           self.Discovered[x][y] = BOARD_UNDISCOVERED
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
    
    self.MineCount = capacity

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

function Board:getRenderTile(x, y)
    assert(_G.Client, "only client can get the rendered part")
    
    return self._render.parts[x][y]
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
    return self:getFlag(x, y) and true or false
end

function Board:getFlag(x, y)
    for _, flag in pairs(self.Flags) do
        if flag.X == x and flag.Y == y then
            return flag
        end
    end
end

function Board:setFlag(x, y, state, owner)
    local tile = self:getTile(x, y)
    if tile == BOARD_UNDISCOVERED and state and not self:getFlag(x, y) then
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

        -- prevent users removing other people's flags when they have been recently placed down
        for i, flag in pairs(self.Flags) do
            if flag.X == x and flag.Y == y then
                if owner and flag.Owner ~= owner and flag.PlacedAt + FLAG_OTHER_COOLDOWN > time() then return end
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
    elseif tile == BOARD_UNDISCOVERED then
        local exploreTiles = {makeTile(startX, startY)}

        while #exploreTiles > 0 do
            local exploreTile = exploreTiles[1]
            local x, y = exploreTile.X, exploreTile.Y
            table.remove(exploreTiles, 1)

            if self:getTile(x, y) == BOARD_UNDISCOVERED then
                local nearbyMines = self:getNearbyMinesCount(x, y)
                self.Discovered[x][y] = nearbyMines
                if self:isFlagged(x, y) then self:setFlag(x, y, false) end

                if nearbyMines == 0 then
                    for _, nearbyTile in pairs(self:getNearbyTiles(x, y)) do
                        if self:getTile(nearbyTile.X, nearbyTile.Y) == BOARD_UNDISCOVERED then
                            table.insert(exploreTiles, nearbyTile) 
                        end
                    end
                end
            end
        end
        
        for _, flag in pairs(self.Flags) do
            local x, y = flag.X, flag.Y
            if self:getTile(x, y) ~= BOARD_UNDISCOVERED and self:getTile(x, y) ~= "Mine" then
                self:setFlag(x, y, false, nil)
            end
        end

        return GameEnum.Discovery.Safe
    end

    return GameEnum.Discovery.Ignore
end

function Board:zeroStart()
    assert(_G.Server, "only server can find a zero spot")

    local radius = self.Options.RandomStartRadius
    local centerX, centerY = math.floor(self.Options.Size.X/2), math.floor(self.Options.Size.Y/2)
    
    if self.Options.Size.X < radius*2 or self.Options.Size.Y < radius*2 then
        radius = 0
    end
    
    local startX, startY = centerX + math.random(-radius, radius), centerY + math.random(-radius, radius)
    local isMine = self:getTile(startX, startY) == "Mine"

    local startTile = not isMine and self:getNearbyMinesCount(startX, startY) or 1

    if startTile > 0 then
        local exploreTiles = {makeTile(startX, startY)}
        local exploredTiles = {}
        
        while #exploreTiles > 0 do
            local tile = exploreTiles[1]
            local x, y = tile.X, tile.Y
            exploredTiles[x] = exploredTiles[x] or {}

            table.remove(exploreTiles, 1)

            if not exploredTiles[x][y] then
                exploredTiles[x][y] = true
                if self:getTile(x, y) ~= "Mine" and self:getNearbyMinesCount(x, y) == 0 then
                    self:discover(x, y)
                    break
                else
                    for _, nearbyTile in pairs(self:getNearbyTiles(x, y)) do
                        exploredTiles[nearbyTile.X] = exploredTiles[nearbyTile.X] or {}
                        if not exploredTiles[nearbyTile.X][nearbyTile.Y] then
                            table.insert(exploreTiles, nearbyTile)
                        end
                    end
                end
            end
        end
    else
        self:discover(startX, startY)
    end
            
    
end

function Board:isVictory()
    assert(_G.Server, "only server can check for victory condition")

    for x, column in pairs(self.Discovered) do
        for y, number in pairs(column) do
            if self:getTile(x, y) ~= "Mine" and number < 0 then
                return false
            end
        end
    end
    
    return true
end

function Board:serialize(noMines)
    return {
        Options = self.Options,
        Discovered = self.Discovered,
        Flags = self.Flags,
        Mines = noMines and {} or self.Mines,
        MineCount = self.MineCount,
        StartedAt = self.StartedAt
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

    self._render.extentsSize = self._render.model:GetExtentsSize()
    self._render.position = CFrame.new(self._render.model:GetPivot().p)
end

function Board:getRenderModel()
    assert(_G.Client, "only client can render the board")
    return self._render.model
end

function Board:getExtents()
    assert(_G.Client, "only client can render the board")
    return self._render.extentsSize
end

function Board:getPosition()
    assert(_G.Client, "only client can render the board")
    return self._render.position
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
            local isMine = self:getTile(x, y) == "Mine"
            part.Label.Text = number > 0 and number or ""
            part.Label.TextColor3 = number > 0 and renderOptions.TextColor[number] or Color3.new()
            part.Instance.CFrame = part.CFrame * CFrame.Angles(number == -2 and math.pi or 0, 0, 0)
            part.Instance.Color = 
                (self.ExplosionAt and self.ExplosionAt.X == x and self.ExplosionAt.Y == y) and renderOptions.PartColor.MineClicked or
                isMine and renderOptions.PartColor.Mine or
                number > 0 and renderOptions.PartColor.DiscoveredNearby or 
                number == 0 and renderOptions.PartColor.DiscoveredZero or 
                useSecondary % 2 == 0 and renderOptions.PartColor.Primary or renderOptions.PartColor.Secondary

            if isMine and not part.HasExploded and self._render.explode then
                part.HasExploded = true
                local attachment = Instance.new("Attachment", part.Instance)
                attachment.Position = Vector3.new(0, part.Size.Y * 2, 0)

                local particles = shared.Assets.MineExplosion:GetChildren()
                for _, particle in pairs(particles) do
                    local p = particle:Clone()
                    p.Parent = attachment
                    p:Emit(p:GetAttribute("Emit") or 1)
                end
            end
            
        end
    end
    
    -- clear any flags placed if they are discovered
    for _, flag in pairs(self.Flags) do
        local x, y = flag.X, flag.Y
        if self:getTile(x, y) ~= BOARD_UNDISCOVERED and self:getTile(x, y) ~= "Mine" then
            self:setFlag(x, y, false, nil)
        end
    end
    
    for i, flag in pairs(self.Flags) do
        local x, y = flag.X, flag.Y
        local flagModel = self._render.flags[flag] or flag.Model:Clone()
        local part = self._render.parts[x][y]
        self._render.flags[flag] = flagModel

        flagModel.Parent = part.Instance
        colorContents(flagModel, Players.LocalPlayer.Name ~= flag.Owner.Name and PlayerChatColor(flag.Owner.Name) or FLAG_DEFAULT_COLOR)
        flagModel:SetPrimaryPartCFrame(part.CFrame * CFrame.new(0, part.Size.Y/2, 0))
    end
end

function Board:postProcess(renderOptions)

end

function Board:destroy()
    if _G.Client then
        for _, flagModel in pairs(self._render.flags) do
            flagModel:Destroy()
        end
        if self._render.model then
            self._render.model:Destroy()
        end
    end
end

return Board