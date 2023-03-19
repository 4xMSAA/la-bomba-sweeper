local Debris = game:GetService("Debris")

local UI = {}
UI.StatusBarMessages = {
    InProgress = {Text = "A round is already in progress - wait for the next one", Color = Color3.fromRGB(255, 219, 34)}
}

--TODO: port over UI code from minesweeper client
function UI.statusBar(text, color)
    
end

function UI.createMessage(text, color, duration)
    assert(text ~= nil, "text cannot be empty")
    assert(type(text) == "string", "text must be a string")

    local messages = UI.ScreenInstance.MessageList
    local messageTemplate = messages.MessageTemplate:Clone()
    color = color or Color3.fromRGB(255, 255, 255)
    duration = duration or 30

    local message = messageTemplate:Clone()
    message.Text = text
    message.TextColor3 = color
    message.Visible = true
    message.Name = text
    message.Parent = messages
    Debris:AddItem(message, duration)
    
end


function UI.createCursor()
    local cursor = shared.Assets.Gui.Templates.Cursor:Clone()
    cursor.Parent = UI.Instance
    return cursor
end

return function(game)
    UI.Game = game
    UI.Instance = game.Gui
    UI.ScreenInstance = UI.Instance:WaitForChild("Screen")
    
    return UI
end