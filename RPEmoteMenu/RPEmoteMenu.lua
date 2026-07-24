local ADDON_NAME = ...

-- 1. DATA STRUCTURE
local sectionOrder = {"THOUGHTS", "REACTIONS", "CONVERSATION", "GESTURES", "POSTURES"}

local sections = {
    THOUGHTS = {
        {"Blank", "/blank"}, {"Gaze", "/gaze"}, {"Ponder", "/e ponders"},
        {"Quiet and thoughtful", "/e grows quiet and thoughtful."},
        {"Watches quietly", "/e watches quietly."}, {"Peer", "/peer"},
        {"Considers that", "/e considers that for a moment."},
        {"Tilts her head", "/e tilts her head slightly."}
    },
    REACTIONS = {
        {"Blink", "/blink"}, {"Nod", "/nod"}, {"Shrug", "/shrug"},
        {"Sigh", "/sigh"}, {"Smirk", "/smirk"},
        {"Inhale", "/e takes a slow, deep breath, closing her eyes for a moment."},
        {"Exhale", "/e exhales slowly and opens her eyes."},
        {"Growl", "/e makes a soft growling noise in her throat."}
    },
    CONVERSATION = {
        {"Says...", "/e says, \""}, {"Asks...", "/e asks, \""},
        {"Faint smile", "/e lets a smile flirt with the corner of her mouth."},
        {"Quiet chuckle", "/e lets out a quiet chuckle."},
        {"Smile", "/smile"}, {"Laugh", "/lol"},
        {"Thanks", "/ty"}, {"Welcome", "/welcome"}
    },
    GESTURES = {
        {"Raise Hand", "/raise"}, {"Point", "/point"}, {"Beckon", "/beckon"},
        {"Wave", "/wave"}, {"Cheer", "/cheer"}, {"Kiss", "/kiss"},
        {"Salute", "/salute"}
    },
    POSTURES = {
        {"Sit", "/sit"}, {"Stand", "/stand"},
        {"Stretch", "/e laces her fingers together and stretches skyward, exhaling slowly before letting her arms fall back to her sides."},
        {"Lean", "/lean"}, {"Bow", "/bow"}, {"Read", "/read"}
    }
}

local expandedStates = {
    THOUGHTS = true,
    REACTIONS = false,
    CONVERSATION = false,
    GESTURES = false,
    POSTURES = false
}

local defaults = {
    locked = false,
    showAtLogin = true,
    rememberMinimized = true,
    minimized = false,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 100
}

local emoteAliases = {
    lol = "LAUGH",
    ty = "THANK"
}

local expandedHeight = 350
local collapsedHeight = 30

local MainFrame
local ScrollFrame
local ScrollChild
local CollapseBtn
local settingsCategory
local buttonsPool = {}
local isWindowCollapsed = false

-- 2. SAVED SETTINGS
local function InitializeDatabase()
    RPEmoteMenuDB = RPEmoteMenuDB or {}

    for key, value in pairs(defaults) do
        if RPEmoteMenuDB[key] == nil then
            RPEmoteMenuDB[key] = value
        end
    end
end

local function RestoreWindowPosition()
    MainFrame:ClearAllPoints()
    MainFrame:SetPoint(
        RPEmoteMenuDB.point,
        UIParent,
        RPEmoteMenuDB.relativePoint,
        RPEmoteMenuDB.x,
        RPEmoteMenuDB.y
    )
end

local function SaveWindowPosition()
    local point, _, relativePoint, x, y = MainFrame:GetPoint(1)

    RPEmoteMenuDB.point = point
    RPEmoteMenuDB.relativePoint = relativePoint
    RPEmoteMenuDB.x = x
    RPEmoteMenuDB.y = y
end

local function ResetWindowPosition()
    RPEmoteMenuDB.point = defaults.point
    RPEmoteMenuDB.relativePoint = defaults.relativePoint
    RPEmoteMenuDB.x = defaults.x
    RPEmoteMenuDB.y = defaults.y
    RestoreWindowPosition()
end

local function ApplyMovementLock()
    MainFrame:SetMovable(not RPEmoteMenuDB.locked)
end

-- 3. COMMAND EXECUTION
local function ExecuteEmoteCommand(command)
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

-- 4. MENU RENDERING
local function GetContainerButton()
    for _, button in ipairs(buttonsPool) do
        if not button:IsShown() then
            return button
        end
    end

    local button = CreateFrame("Button", nil, ScrollChild)
    button:SetSize(210, 22)

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.Text:SetPoint("LEFT", button, "LEFT", 22, 0)
    button.Text:SetJustifyH("LEFT")

    table.insert(buttonsPool, button)
    return button
end

local function UpdateMenu()
    for _, button in ipairs(buttonsPool) do
        button:Hide()
        button:ClearAllPoints()
        button:SetScript("OnClick", nil)
    end

    local dynamicY = 0

    for _, sectionName in ipairs(sectionOrder) do
        local isExpanded = expandedStates[sectionName]
        local marker

        if isExpanded then
            marker = "|TInterface\\Buttons\\UI-MinusButton-Up:16:16:0:0|t "
        else
            marker = "|TInterface\\Buttons\\UI-PlusButton-Up:16:16:0:0|t "
        end

        local header = GetContainerButton()
        header:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 5, -dynamicY)
        header.Text:SetText(marker .. sectionName)
        header.Text:SetTextColor(0.8, 0.8, 0.8)
        header:SetScript("OnClick", function()
            expandedStates[sectionName] = not expandedStates[sectionName]
            UpdateMenu()
        end)
        header:Show()

        dynamicY = dynamicY + 24

        if isExpanded then
            for _, item in ipairs(sections[sectionName]) do
                local label, command = item[1], item[2]
                local emoteButton = GetContainerButton()

                emoteButton:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 15, -dynamicY)
                emoteButton.Text:SetText(label)
                emoteButton.Text:SetTextColor(1, 1, 1)
                emoteButton:SetScript("OnClick", function()
                    ExecuteEmoteCommand(command)
                end)
                emoteButton:Show()

                dynamicY = dynamicY + 22
            end
        end

        dynamicY = dynamicY + 4
    end

    ScrollChild:SetHeight(math.max(dynamicY, 1))
end

-- 5. WINDOW COLLAPSE
local function AnchorFrameByTopLeft()
    local left = MainFrame:GetLeft()
    local top = MainFrame:GetTop()

    if left and top then
        MainFrame:ClearAllPoints()
        MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
end

local function UpdateWindowCollapse()
    -- Keep the title bar fixed while the bottom edge rises or falls.
    AnchorFrameByTopLeft()

    if isWindowCollapsed then
        ScrollFrame:Hide()
        MainFrame:SetHeight(collapsedHeight)
        CollapseBtn:SetText("+")
    else
        MainFrame:SetHeight(expandedHeight)
        ScrollFrame:Show()
        CollapseBtn:SetText("-")
        UpdateMenu()
    end

    if RPEmoteMenuDB.rememberMinimized then
        RPEmoteMenuDB.minimized = isWindowCollapsed
    end
end

-- 6. MAIN WINDOW
local function CreateMainWindow()
    MainFrame = CreateFrame("Frame", "RPEmoteMenu", UIParent, "BackdropTemplate")
    MainFrame:SetSize(250, expandedHeight)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag("LeftButton")

    MainFrame:SetScript("OnDragStart", function(self)
        if not RPEmoteMenuDB.locked then
            self:StartMoving()
        end
    end)

    MainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPosition()
    end)

    MainFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1
    })
    MainFrame:SetBackdropColor(0.12, 0.12, 0.12, 1)
    MainFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    local title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 10, -10)
    title:SetText("RP Emote Menu")
    title:SetTextColor(1, 1, 1, 1)

    ScrollFrame = CreateFrame("ScrollFrame", nil, MainFrame, "UIPanelScrollFrameTemplate")
    ScrollFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 5, -35)
    ScrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -25, 10)

    ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollChild:SetSize(220, 1)
    ScrollFrame:SetScrollChild(ScrollChild)

    CollapseBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    CollapseBtn:SetSize(22, 20)
    CollapseBtn:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -5, -5)
    CollapseBtn:SetScript("OnClick", function()
        isWindowCollapsed = not isWindowCollapsed
        UpdateWindowCollapse()
    end)

    RestoreWindowPosition()
    ApplyMovementLock()

    if RPEmoteMenuDB.rememberMinimized then
        isWindowCollapsed = RPEmoteMenuDB.minimized
    else
        isWindowCollapsed = false
    end

    UpdateWindowCollapse()

    if RPEmoteMenuDB.showAtLogin then
        MainFrame:Show()
    else
        MainFrame:Hide()
    end
end

-- 7. SETTINGS PANEL
local function CreateCheckbox(parent, label, y, getValue, setValue)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    checkbox:SetChecked(getValue())

    local checkboxLabel = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    checkboxLabel:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    checkboxLabel:SetText(label)

    checkbox:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
    end)

    return checkbox
end

local function CreateSettingsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "RP Emote Menu"

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("RP Emote Menu")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetText("Configure the RP Emote Menu window.")
    description:SetTextColor(0.8, 0.8, 0.8)

    CreateCheckbox(
        panel,
        "Lock window movement",
        -70,
        function()
            return RPEmoteMenuDB.locked
        end,
        function(value)
            RPEmoteMenuDB.locked = value
            ApplyMovementLock()
        end
    )

    CreateCheckbox(
        panel,
        "Show the addon at login",
        -105,
        function()
            return RPEmoteMenuDB.showAtLogin
        end,
        function(value)
            RPEmoteMenuDB.showAtLogin = value
        end
    )

    CreateCheckbox(
        panel,
        "Remember whether the main window was minimized",
        -140,
        function()
            return RPEmoteMenuDB.rememberMinimized
        end,
        function(value)
            RPEmoteMenuDB.rememberMinimized = value

            if value then
                RPEmoteMenuDB.minimized = isWindowCollapsed
            else
                RPEmoteMenuDB.minimized = false
            end
        end
    )

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(170, 24)
    resetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -190)
    resetButton:SetText("Reset Window Position")
    resetButton:SetScript("OnClick", ResetWindowPosition)

    settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(settingsCategory)
end

local function OpenSettings()
    if settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end

-- 8. SLASH COMMANDS
local function HandleSlashCommand(message)
    local command = string.lower(strtrim(message or ""))

    if command == "config" or command == "options" or command == "settings" then
        OpenSettings()
        return
    end

    if command == "" then
        if MainFrame:IsShown() then
            MainFrame:Hide()
        else
            MainFrame:Show()
            UpdateMenu()
        end
        return
    end

    print("|cffffd100RP Emote Menu:|r /emotes, /emotes config, /emotes options, /emotes settings")
end

-- 9. INITIALIZATION
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, loadedAddonName)
    if loadedAddonName ~= ADDON_NAME then
        return
    end

    InitializeDatabase()
    CreateMainWindow()
    CreateSettingsPanel()

    SLASH_ELLEMOTE1 = "/emotes"
    SlashCmdList["ELLEMOTE"] = HandleSlashCommand

    eventFrame:UnregisterEvent("ADDON_LOADED")
end)
