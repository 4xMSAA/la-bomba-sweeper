local DEFAULT_RENDER_OPTIONS = _G.CONFIGURATION.DEFAULT_RENDER_OPTIONS

local Maid = require(shared.Common.Maid)


---board idk
---@class Board
local Board = {}
Board.__index = Board

function Board.new(options, renderOptions)
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
           self.Discovered[x][y] = 0
        end
    end


    setmetatable(self, Board)
    Maid.watch(self)

    return self
end

function Board:serialize(noMines)
    return {
        Options = self.Options,
        Discovered = self.Discovered,
        Flags = self.Flags,
        Mines = noMines and nil or self.Mines,
    }
end

if _G.Client then function Board:route()
    
end end

if _G.Server then function Board:route()

end end

function Board:render()
    assert(_G.Client, "only client can render the board")
    
    
end