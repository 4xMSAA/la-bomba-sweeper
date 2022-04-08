local Maid = require(shared.Common.Maid)
local NetworkLib = require(shared.Common.NetworkLib)
local GameEnum = shared.GameEnum
local log, logwarn = require(shared.Common.Log)(script:GetFullName())

local MinesweeperNetworker = require(_G.Server.Game.MinesweeperNetworker)
local Board = require(shared.Game.Board)

---A class description
---@class Minesweeper
local Minesweeper = {}
Minesweeper.__index = Minesweeper

function Minesweeper.new(server, options)
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

    NetworkLib:send(GameEnum.PacketType.GameState, GameEnum.GameState.Begin, {Players = self.Playing})
    self.GameState = GameEnum.GameState.InProgress

end

function Minesweeper:gameEnd()
    self.Playing = {}
    self.Board:destroy()

    NetworkLib:send(GameEnum.PacketType.GameState, GameEnum.GameState.CleanUp, {Mines = self.Board.Mines})
end

function Minesweeper:adhocClient(client)
    log(1, client, "joined adhoc")
    NetworkLib:sendTo(
        client, 
        GameEnum.PacketType.GameState,
        GameEnum.GameState.InProgress, 
        {Board = self.Board:serialize(true), Players = self.Playing}
    )
end

function Minesweeper:route(packet, player, ...)
    MinesweeperNetworker[packet](self, player, ...)
end

return function(server, options)
    local game = Minesweeper.new(server, options)
    
    game.ClientManager.ClientAdded:connect(function(client)
        if game.GameState == GameEnum.GameState.InProgress then
            game:adhocClient(client)
        end
    end)
    game:gameBegin()
end