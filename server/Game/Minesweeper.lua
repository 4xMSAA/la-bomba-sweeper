local CURSOR_UPDATE_TICK = _G.TIMERS.CURSOR_UPDATE
local BADGES = _G.BADGES

local BadgeService = game:GetService("BadgeService")

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

        StartedAt = 0,
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

    self.Board:zeroStart()
    self.StartedAt = time()

    NetworkLib:send(GameEnum.PacketType.GameState, GameEnum.GameState.Begin.ID, {
        Board = self.Board:serialize(true),
        Players = clientsToPlayers(self.Playing)
    })
    self.GameState = GameEnum.GameState.InProgress

end

function Minesweeper:gameEnd(victory, explosionAt, who)
    self.GameState = GameEnum.GameState.CleanUp

    if victory == true then
        for _, client in pairs(self.Playing) do
            BadgeService:AwardBadge(client.ID, BADGES.ONE_VICTORY)
        end

        playSoundFrom(shared.Assets.Sounds.Victory)
        NetworkLib:send(GameEnum.PacketType.GameState,
            GameEnum.GameState.GameOver.ID,
            true,
            {Discovered = self.Board.Discovered, Mines = self.Board.Mines, TimeTaken = time() - self.StartedAt}
        )
    elseif victory == false then
        playSoundFrom(shared.Assets.Sounds.Explode)
        NetworkLib:send(
            GameEnum.PacketType.GameState, 
            GameEnum.GameState.GameOver.ID,
            false,
            {Discovered = self.Board.Discovered, ExplosionAt = explosionAt, Mines = self.Board.Mines, Who = who:serialize()}
        )
    else
        NetworkLib:send(GameEnum.PacketType.GameState,
            GameEnum.GameState.GameOver.ID,
            "neutral",
            {Discovered = self.Board.Discovered, Mines = self.Board.Mines, TimeTaken = time() - self.StartedAt}
        )
    end

    self.Playing = {}
    
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
        {Adhoc = true, Board = self.Board:serialize(true), Discovered = self.Board.Discovered, Players = clientsToPlayers(self.Playing)}
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
        repeat task.wait() until client.IsReady

        BadgeService:AwardBadge(client.ID, BADGES.WELCOME)

        if game.GameState == GameEnum.GameState.InProgress then
            game:adhocClient(client)
        end
        
        for clientID, _ in pairs(game.Cursors) do
            log(2, "sending cursor from", clientID, "to", client.Name)
            NetworkLib:sendTo(
                client, 
                GameEnum.PacketType.CursorUpdate,
                "add",
                game.ClientManager:getClientByID(clientID)
            )
        end

        game.Cursors[client.ID] = Vector3.new()
        NetworkLib:send(GameEnum.PacketType.CursorUpdate, "add", client)
    end)
    
    game.ClientManager.ClientRemoving:connect(function(client)
        for i, playingClient in pairs(game.Playing) do
            if playingClient == client  then
                table.remove(game.Playing, i)
            end
        end

        game.Cursors[client.ID] = nil
        NetworkLib:send(GameEnum.PacketType.CursorUpdate, "remove", client.ID)
        
        if #game.Playing == 0 and game.GameState == GameEnum.GameState.InProgress then
            game:gameEnd("neutral")
        end
    end)
    
    -- TODO: ugly... fix later
    coroutine.wrap(function()
        while task.wait(1) do
            if game.GameState == GameEnum.GameState.GameOver then
                if #game.ClientManager:getClients() > 0 then
                    game:gameBegin()
                end
            end
        end
    end)()
    
    while task.wait(CURSOR_UPDATE_TICK) do
        NetworkLib:send(GameEnum.PacketType.CursorUpdate, "update", game.Cursors)
    end
end