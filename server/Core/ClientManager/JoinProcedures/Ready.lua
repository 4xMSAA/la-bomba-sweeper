local GameEnum = shared.GameEnum
local NetworkLib = require(shared.Common.NetworkLib)
local log, logwarn = require(shared.Common.Log)(script:GetFullName())


local Ready = {
    Priority = GameEnum.Priority.Last
}

function Ready.Run(client)
    local bind
    bind = NetworkLib:listenFor(GameEnum.PacketType.Ready, function(player)
        log(2, "received Ready packet from", player, player.UserId, " - looking for:", client.Name, "with ID of", client.ID)
        if player.UserId == client.ID then
            log(1, player, "is ready")
            client.IsReady = true
            bind:disconnect()
            bind = nil
        end
    end)

    -- hold on to the name in event the client leaves beforehand?
    local name = client.Name
    repeat 
        task.wait(10)
    until not bind or not Players:FindFirstChild(name)
    
    if bind then
        bind:disconnect()
    end
end

return Ready
