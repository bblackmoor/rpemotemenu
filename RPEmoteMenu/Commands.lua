local _, addon = ...

addon.Commands = {}

local emoteAliases = addon.EmoteAliases

-- COMMAND EXECUTION
local function GetUnitDisplayName(unit)
    local name = UnitName(unit)
    return type(name) == "string" and name or ""
end

local function ReplaceCommandTokens(command)
    local replacements = {
        ["{target}"] = GetUnitDisplayName("target"),
        ["{player}"] = GetUnitDisplayName("player")
    }

    for token, value in pairs(replacements) do
        local pattern = string.gsub(token, "(%W)", "%%%1")
        command = string.gsub(command, pattern, function()
            return value
        end)
    end

    return command
end

local function HasOtherTarget()
    return UnitExists("target") and not UnitIsUnit("target", "player")
end

function addon.Commands.ExecuteEmoteCommand(defaultCommand, targetedCommand)
    local command = defaultCommand

    if HasOtherTarget() and targetedCommand and targetedCommand ~= "" then
        command = targetedCommand
    end

    command = ReplaceCommandTokens(command)

    if string.sub(command, -1) == '"' then
        ChatFrame_OpenChat(command, DEFAULT_CHAT_FRAME)
        return
    end

    local customText = string.match(command, "^/e%s+(.+)$")
    if customText then
        C_ChatInfo.SendChatMessage(customText, "EMOTE")
        return
    end

    local slashCommand = string.match(command, "^/(%S+)$")
    if slashCommand then
        local token = emoteAliases[string.lower(slashCommand)] or string.upper(slashCommand)
        DoEmote(token)
        return
    end

    ChatFrame_OpenChat(command, DEFAULT_CHAT_FRAME)
end
