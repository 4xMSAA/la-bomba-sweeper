local GameEnum = shared.GameEnum

local RESPONSES = {
    [GameEnum.PacketType.SetFlagState] = function(game, player, state, x, y)
        local client = game.ClientManager:getClientBy(player)
        if not game.Playing[client] then return end

        game.Board:setFlagBy(player, x, y)
        NetworkLib:send(GameEnum.PacketType.SetFlagState, player, state, x, y)
    end,

    [GameEnum.PacketType.CursorUpdate] = function(game, player, x, y, z)
        local client = game.ClientManager:getClientBy(player)
        if not game.Playing[client] then return end

        local cursor = game.Cursors[client]
        cursor.X = x
        cursor.Y = y
        cursor.Z = z
        
        NetworkLib:send(GameEnum.PacketType.CursorUpdate, player, x, y, z)
    end,
    
    [GameEnum.PacketType.Discover] = function(game, player, x, y)
        local client = game.ClientManager:getClientBy(player)
        if not game.Playing[client] then return end
        
        local response = game.Board:discover(x, y)
    end,
}

return RESPONSES