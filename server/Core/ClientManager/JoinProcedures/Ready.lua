local GameEnum = shared.GameEnum

local Ready = {
    Priority = GameEnum.Priority.Last
}

function Ready.Run(client)
    -- perform additional checks if player is ready

    client.IsReady = true
end

return Ready
