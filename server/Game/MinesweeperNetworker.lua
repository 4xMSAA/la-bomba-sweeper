local GameEnum = shared.GameEnum

local RESPONSES = {
    [GameEnum.PacketType.SetFlagState] = function(game, client, state, x, y)
        if not game.Playing[client] then return end

        game.Board:setFlagBy(player, x, y)
        NetworkLib:send(GameEnum.PacketType.SetFlagState, client, state, x, y)
    end,

    [GameEnum.PacketType.CursorUpdate] = function(game, client, x, y, z)
        if not game.Playing[client] then return end

        local cursor = game.Cursors[client]
        cursor.X = x
        cursor.Y = y
        cursor.Z = z
        
        NetworkLib:send(GameEnum.PacketType.CursorUpdate, player, x, y, z)
    end,
    
    [GameEnum.PacketType.Discover] = function(game, client, x, y)
        if not game.Playing[client] then return end
        
        local response = game.Board:discover(x, y)
        if response == GameEnum.Discovery.Mine then
            game:gameEnd()
        end
    end,
}

return RESPONSES