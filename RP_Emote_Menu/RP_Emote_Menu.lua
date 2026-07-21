-- 1. DATA STRUCTURE (Mirrors your AHK Sections Map)
local sectionOrder = {"THOUGHTS", "REACTIONS", "CONVERSATION", "GESTURES", "POSTURES"}
local sections = {
    THOUGHTS = {
        {"Blank", "/blank"}, {"Gaze", "/gaze"}, {"Ponder", "/e ponders"},
        {"Quiet and thoughtful", "/e grows quiet and thoughtful."},
        {"Watches quietly", "/e watches quietly."}, {"Peer", "/peer"},
        {"Considers that", "/e considers that for a moment."}, {"Tilts her head", "/e tilts her head slightly."}
    },
    REACTIONS = {
        {"Blink", "/blink"}, {"Nod", "/nod"}, {"Shrug", "/shrug"}, {"Sigh", "/sigh"}, {"Smirk", "/smirk"},
        {"Inhale", "/e takes a slow, deep breath, closing her eyes for a moment."},
        {"Exhale", "/e exhales slowly and opens her eyes."}, {"Growl", "/e makes a soft growling noise in her throat."}
    },
    CONVERSATION = {
        {"Says...", "/e says, \""}, {"Asks...", "/e asks, \""},
        {"Faint smile", "/e lets a smile flirt with the corner of her mouth."},
        {"Quiet chuckle", "/e lets out a quiet chuckle."}, {"Smile", "/smile"}, {"Laugh", "/lol"},
        {"Thanks", "/ty"}, {"Welcome", "/welcome"}
    },
    GESTURES = {
        {"Raise Hand", "/raise"}, {"Point", "/point"}, {"Beckon", "/beckon"},
        {"Wave", "/wave"}, {"Cheer", "/cheer"}, {"Kiss", "/kiss"}, {"Salute", "/salute"}
    },
    POSTURES = {
        {"Sit", "/sit"}, {"Stand", "/stand"},
        {"Stretch", "/e laces her fingers together and stretches skyward, exhaling slowly before letting her arms fall back to her sides."},
        {"Lean", "/lean"}, {"Bow", "/bow"}, {"Read", "/read"}
    }
}

-- Track expansion state independently for every section (Allows multiple open)
local expandedStates = {
    THOUGHTS = true,
    REACTIONS = false,
    CONVERSATION = false,
    GESTURES = false,
    POSTURES = false
}

-- 2. MAIN WINDOW FRAME CREATION
local MainFrame = CreateFrame("Frame", "RPEmoteMenu", UIParent, "BackdropTemplate")
MainFrame:SetSize(250, 350)
MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
MainFrame:SetMovable(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)

-- Dark Theme Styling
MainFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeSize = 1,
})
MainFrame:SetBackdropColor(0.12, 0.12, 0.12, 1) -- #202020 background
MainFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

-- Title Bar
local Title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
Title:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 10, -10)
Title:SetText("RP Quick Emotes")
Title:SetTextColor(1, 1, 1, 1)


-- 3. THE SCROLLING CONTAINER
-- ScrollFrame acts as the viewing window
local ScrollFrame = CreateFrame("ScrollFrame", nil, MainFrame, "UIPanelScrollFrameTemplate")
ScrollFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 5, -35)
ScrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -25, 10)

-- ScrollChild acts as the physical surface that moves up and down
local ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
ScrollChild:SetSize(220, 1) -- Height scales automatically later
ScrollFrame:SetScrollChild(ScrollChild)

-- Object pooling pools to reuse buttons and prevent game memory lag
local buttonsPool = {}

local function GetContainerButton()
    for _, btn in ipairs(buttonsPool) do
        if not btn:IsShown() then return btn end
    end
    
    -- Create button if pool is empty
    local btn = CreateFrame("Button", nil, ScrollChild, "BackdropTemplate")
    btn:SetSize(210, 22)
    
    btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.Text:SetPoint("LEFT", btn, "LEFT", 10, 0)
    
    table.insert(buttonsPool, btn)
    return btn
end

-- 4. COMMAND EXECUTION AND RENDERING

local emoteAliases = {
    lol = "LAUGH",
    ty = "THANK",
}

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

local function UpdateMenu()
    for _, btn in ipairs(buttonsPool) do
        btn:Hide()
        btn:ClearAllPoints()
    end

    local dynamicY = 0

    for _, sectionName in ipairs(sectionOrder) do
        local isExpanded = expandedStates[sectionName]
        local marker = isExpanded and "- " or "+ "

        local header = GetContainerButton()
        header:ClearAllPoints()
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

                local emoteBtn = GetContainerButton()
                emoteBtn:ClearAllPoints()
                emoteBtn:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 15, -dynamicY)
                emoteBtn.Text:SetText(label)
                emoteBtn.Text:SetTextColor(1, 1, 1)

                emoteBtn:SetScript("OnClick", function()
                    ExecuteEmoteCommand(command)
                end)

                emoteBtn:Show()
                dynamicY = dynamicY + 22
            end
        end

        dynamicY = dynamicY + 4
    end

    ScrollChild:SetHeight(dynamicY)
end

-- 5. TITLE-BAR COLLAPSE BUTTON
local expandedHeight = 350
local collapsedHeight = 30
local isWindowCollapsed = false

local CollapseBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
CollapseBtn:SetSize(22, 20)
CollapseBtn:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -5, -5)

local function AnchorFrameByTopLeft()
    local left = MainFrame:GetLeft()
    local top = MainFrame:GetTop()

    if left and top then
        MainFrame:ClearAllPoints()
        MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
end

local function UpdateWindowCollapse()
    -- Re-anchor by the top-left corner so changing the height moves only
    -- the bottom edge. The title bar therefore stays in place.
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
end

CollapseBtn:SetScript("OnClick", function()
    isWindowCollapsed = not isWindowCollapsed
    UpdateWindowCollapse()
end)

-- 6. INITIALIZATION SLASH COMMAND
SLASH_ELLEMOTE1 = "/emotes"
SlashCmdList["ELLEMOTE"] = function()
    if MainFrame:IsShown() then MainFrame:Hide() else MainFrame:Show() UpdateMenu() end
end

-- Initialize display elements
UpdateMenu()
UpdateWindowCollapse()
