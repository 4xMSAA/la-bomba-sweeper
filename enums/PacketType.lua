local TableUtils = require(shared.Common.TableUtils)

---@class PacketType
local GameEnum = {
    {"Ready", "Ready signals to send between client and server"},
    {"GameInfo", "Data about the game's settings"},
    {"AdhocClient", "Send an ad-hoc client information about the game state that it isn't aware of"},
    
    {"PlaySound", "Plays a global sound or a positional sound"},
    {"GameState", "Game over, game start or other messages"},
    {"Discover", "Client sends a place to discover"},
    {"SetFlagState", "On send, client wants to set or remove a flag at (x,y); on receive, (x,y) and owner"},
    {"CursorUpdate", "Send server cursor information or receive other players' cursor information"}

}

return TableUtils.toEnumList(script.Parent.Name, GameEnum)
