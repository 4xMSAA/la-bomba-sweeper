local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local PlayerChatColor = require(shared.Common.PlayerChatColor)

local GameEnum = shared.GameEnum

local UI = {}
UI.StatusBarMessages = {
    InProgress = {Text = "A round is already in progress - wait for the next one", Color = Color3.fromRGB(255, 219, 34)}
}

--TODO: port over UI code from minesweeper client
function UI.statusBar(text, color)
    
end

function UI.updateMouseHover()
    local infoBox = UI.Instance.InfoBox
    local flagInfo = infoBox.FlagInfo
    local game = UI.Game
    local mouseLocation = UserInputService:GetMouseLocation()

    infoBox.Position = UDim2.new(0, mouseLocation.X, 0, mouseLocation.Y)

    if game.GameState == GameEnum.GameState.InProgress or game.GameState == GameEnum.GameState.CleanUp and game.Board then
        local tile = game.Board:mouseToBoard(game.Client.Mouse.Hit.Position)

        -- flag info
        if tile and game.Board:isFlagged(tile.X, tile.Y) then
            local flag = game.Board:getFlag(tile.X, tile.Y)
            flagInfo.DisplayName.Text = flag.Owner.DisplayName
            flagInfo.DisplayName.TextColor3 = PlayerChatColor(flag.Owner.Name)
            flagInfo.Visible = flag.Owner == Players.LocalPlayer and false or true
        else
            flagInfo.Visible = false
        end 
    else
        flagInfo.Visible = false
    end
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