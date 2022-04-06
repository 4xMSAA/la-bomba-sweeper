local DEFAULT_OPTIONS = _G.CONFIGURATION.GENERATION

local Maid = require(shared.Common.Maid)

local MinesweeperNetworker = require(_G.Server.Game.MinesweeperNetworker)

---A class description
---@class Minesweeper
local Minesweeper = {}
Minesweeper.__index = Minesweeper

function Minesweeper.new(args)
    local self = {
        ClientManager = server.ClientManager,

        Playing = {},
        Cursors = {},
        
        Board = nil,

        GameState = GameEnum.GameState.Begin
    }

    local function routeWrapper(player, packetType, ...)
        self:route(packetType, self.ClientManager:getClientBy(player), ...)
    end

    self._NetworkListener = NetworkLib:listen(routeWrapper)

    setmetatable(self, Minesweeper)
    Maid.watch(self)

    return self
end

function Minesweeper:gameBegin()

    self.Playing = {}

    for _, client in pairs(self.ClientManager:getClients()) do
        table.insert(self.Playing, client)
    end
    
    self.Board = Board.new()

    NetworkLib:send(GameEnum.GameState.Begin, {Players = self.Playing})
    self.GameState = GameEnum.GameState.InProgress

end

function Minesweeper:gameEnd()
    self.Playing = {}

    NetworkLib:send(GameEnum.GameState.CleanUp, {Mines = self.Board.Mines})
end

function Minesweeper:adhocClient(client)
    NetworkLib:sendTo(client, GameEnum.GameState.InProgress, {Board = self.Board:serialize(true), Players = self.Playing})
end

function Minesweeper:route(packet, player, ...)
    MinesweeperNetworker[packet](self, player, ...)
end