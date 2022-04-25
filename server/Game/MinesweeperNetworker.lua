local NetworkLib = require(shared.Common.NetworkLib)
local GameEnum = shared.GameEnum

local function getClientFromList(clients, targetClient)
    for _, client in pairs(clients) do
        if client == targetClient then
            return true
        end
    end

    return false
end

local RESPONSES = {
    [GameEnum.PacketType.SetFlagState] = function(game, client, x, y, state)
        if not getClientFromList(game.Playing, client) then return end
        assert(type(state) == "boolean")

        game.Board:setFlag(x, y, state, client.Instance)
        NetworkLib:send(GameEnum.PacketType.SetFlagState, x, y, state, client.Instance)
    end,

    [GameEnum.PacketType.CursorUpdate] = function(game, client, x, z)
        if not getClientFromList(game.Playing, client) then return end

        -- local cursor = game.Cursors[client]
        -- cursor.X = x
        -- cursor.Y = y
        -- cursor.Z = z
        
        NetworkLib:send(GameEnum.PacketType.CursorUpdate, client, x, z)
    end,
    
    [GameEnum.PacketType.Discover] = function(game, client, x, y)
        if not getClientFromList(game.Playing, client) then return end
        
        local response = game.Board:discover(x, y)
        if game.Board:isVictory() then
            game:gameEnd(true, {X = x, Y = y}, client)
        elseif response == GameEnum.Discovery.Mine then
            game:gameEnd(false, {X = x, Y = y}, client)
        else
            NetworkLib:send(GameEnum.PacketType.Discover, game.Board.Discovered)
        end
    end,
}

return RESPONSES