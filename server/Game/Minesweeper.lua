local Maid = require(shared.Common.Maid)
local NetworkLib = require(shared.Common.NetworkLib)
local GameEnum = shared.GameEnum
local log, logwarn = require(shared.Common.Log)(script:GetFullName())

local MinesweeperNetworker = require(_G.Server.Game.MinesweeperNetworker)
local Board = require(shared.Game.Board)

local function playSoundFrom(folder)
    local len = #folder:GetChildren()
    local sound = folder:GetChildren()[math.random(len)]
    
    NetworkLib:send(GameEnum.PacketType.PlaySound, sound)
end

local function clientsToPlayers(clients)
    local result = {}

    for i, client in pairs(clients) do
        result[i] = client.Instance
    end
    
    return result
end

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

        GameState = GameEnum.GameState.GameOver
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
    self.Board:generate()

    NetworkLib:send(GameEnum.PacketType.GameState, GameEnum.GameState.Begin.ID, {Players = clientsToPlayers(self.Playing)})
    self.GameState = GameEnum.GameState.InProgress

end

function Minesweeper:gameEnd(victory, explosionAt, who)
    self.Playing = {}
    self.GameState = GameEnum.GameState.CleanUp

    if victory then
        playSoundFrom(shared.Assets.Sounds.Victory)
        NetworkLib:send(GameEnum.PacketType.GameState,
            GameEnum.GameState.GameOver.ID,
            true,
            {Mines = self.Board.Mines}
        )
    else
        playSoundFrom(shared.Assets.Sounds.Explode)
        NetworkLib:send(
            GameEnum.PacketType.GameState, 
            GameEnum.GameState.GameOver.ID,
            false,
            -- TODO: ugly hack. fix auto serialize inside tables
            {ExplosionAt = explosionAt, Mines = self.Board.Mines, Who = who:serialize()}
        )
    end
    
    self.Board:destroy()
    task.wait(6)
    self.GameState = GameEnum.GameState.GameOver
end

function Minesweeper:adhocClient(client)
    log(1, client, "joined adhoc")
    NetworkLib:sendTo(
        client, 
        GameEnum.PacketType.GameState,
        GameEnum.GameState.InProgress.ID, 
        {Adhoc = true, Board = self.Board:serialize(true), Players = clientsToPlayers(self.Playing)}
    )
end

function Minesweeper:route(packet, player, ...)
    if MinesweeperNetworker[packet] then
        MinesweeperNetworker[packet](self, player, ...)
    end
end

return function(server, options)
    local game = Minesweeper.new(server, options)
    
    game.ClientManager.ClientAdded:connect(function(client)
        if game.GameState == GameEnum.GameState.InProgress then
            game:adhocClient(client)
        end
    end)
    
    while task.wait(1) do
        if game.GameState == GameEnum.GameState.GameOver then
            if #game.ClientManager:getClients() > 0 then
                game:gameBegin()
            end
        end
    end
end