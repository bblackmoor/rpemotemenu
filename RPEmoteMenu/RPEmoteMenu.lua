local ADDON_NAME = ...

-- DATA STRUCTURE
--
-- EMOTE ENTRY FORMAT
-- Each entry contains:
--     {"Button label", "default command", "targeted command"}
--
-- The targeted command is optional. It is used only when a target exists and
-- that target is not your own character. Otherwise, the default command is used.
--
-- Example:
--     {"Observe",
--      "/e watches quietly.",
--      "/e watches {target} quietly."}
--
-- Tokens supported in either command:
--     {target}       Target's name without the realm.
--     {target-full}  Target's name including the realm when applicable.
--     {player}       Your character's name without the realm.
--     {player-full}  Your character's name including the realm when applicable.
--
-- Blizzard also supports %t in many chat commands as the current target's name,
-- but the {target} tokens above are expanded by this addon before the command
-- is sent and are therefore easier to use consistently in custom emotes.

local defaultSections = {
    -- Category 1
    {
        name = "Favorites",
        emotes = {
            {"Wave", "/wave"},
            {"Cheer", "/cheer"},
            {"Clap", "/clap"},
            {"Cackle", "/cackle"},
            {"Lean", "/lean"},
            {"Look", "/look"},
            {"Pat", "/pat"},
            {"Point", "/point"},
            {"Salute", "/salute"}
        }
    },

    -- Category 2
    {
        name = "Thoughts",
        emotes = {
            {"Blank", "/blank"},
            {"Gaze", "/gaze"},
            {"Ponder", "/e pauses to ponder.", "/e regards {target} thoughtfully, pausing to ponder."},
            {"Quiet and thoughtful", "/e grows quiet and thoughtful.", "/e grows quiet and thoughtful as she considers {target}."},
            {"Watches quietly", "/e watches quietly.", "/e watches {target} quietly."},
            {"Peer", "/peer"},
            {"Considers that", "/e considers that for a moment.", "/e considers {target}'s words for a moment."},
            {"Tilts her head", "/e tilts her head slightly.", "/e tilts her head slightly at {target}."}
        }
    },

    -- Category 3
    {
        name = "Reactions",
        emotes = {
            {"Blink", "/blink"},
            {"Nod", "/nod"},
            {"Shrug", "/shrug"},
            {"Sigh", "/sigh"},
            {"Smirk", "/smirk"},
            {"Inhale", "/e takes a slow, deep breath, closing her eyes for a moment."},
            {"Exhale", "/e exhales slowly and opens her eyes.", "/e exhales slowly, opening her eyes to look at {target}."},
            {"Growl", "/e makes a soft growling noise in her throat.", "/e makes a soft growling noise in her throat at {target}."}
        }
    },

    -- Category 4
    {
        name = "Conversation",
        emotes = {
            {"Says...", "/e says, \"", "/e says to {target}, \""},
            {"Asks...", "/e asks, \"", "/e asks {target}, \""},
            {"Faint smile", "/e lets a faint smile flirt with the corner of her mouth.", "/e lets a faint smile flirt with the corner of her mouth as she regards {target}."},
            {"Quiet chuckle", "/e lets out a quiet chuckle.", "/e lets out a quiet chuckle at {target}."},
            {"Smile", "/smile"},
            {"Laugh", "/lol"},
            {"Thanks", "/ty"},
            {"Welcome", "/welcome"}
        }
    },

    -- Category 5
    {
        name = "Gestures",
        emotes = {
            {"Raise Hand", "/raise"},
            {"Point", "/point"},
            {"Beckon", "/beckon"},
            {"Wave", "/wave"},
            {"Cheer", "/cheer"},
            {"Kiss", "/kiss"},
            {"Salute", "/salute"}
        }
    },

    -- Category 6
    {
        name = "Postures",
        emotes = {
            {"Sit", "/sit"},
            {"Stand", "/stand"},
            {"Stretch", "/e laces her fingers together and stretches skyward, exhaling slowly before letting her arms fall back to her sides."},
            {"Lean", "/lean"},
            {"Bow", "/bow"},
            {"Read", "/read"}
        }
    },

    -- Category 7
    {
        name = "",
        emotes = {
        }
    },

    -- Category 8
    {
        name = "",
        emotes = {
        }
    },

    -- Category 9
    {
        name = "",
        emotes = {
        }
    },

    -- Category 10
    {
        name = "",
        emotes = {
        }
    }
}

local MAX_CATEGORIES = #defaultSections
local MAX_EMOTES = 10
local selectedCategoryIndex = 1

local function Trim(value)
    return strtrim(value or "")
end

local function CopyDefaultCategories()
    local categories = {}

    for categoryIndex, sourceCategory in ipairs(defaultSections) do
        local category = {
            name = sourceCategory.name,
            emotes = {}
        }

        for emoteIndex = 1, MAX_EMOTES do
            local source = sourceCategory.emotes[emoteIndex]
            category.emotes[emoteIndex] = {
                label = source and source[1] or "",
                defaultCommand = source and source[2] or "",
                targetedCommand = source and source[3] or ""
            }
        end

        categories[categoryIndex] = category
    end

    return categories
end

local defaults = {
    locked = false,
    hideSettingsGear = false,
    showAtLogin = true,
    rememberMinimized = true,
    minimized = false,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 100,
    width = 250,
    height = 250,
    emoteDataVersion = 5
}

local emoteAliases = {
    lol = "LAUGH",
    ty = "THANK"
}

local collapsedHeight = 30
local minimumWidth = 250
local minimumHeight = 150
local maximumWidth = 400
local maximumHeight = 400

local MainFrame
local ScrollFrame
local ScrollChild
local CollapseBtn
local SettingsBtn
local ResizeGrip
local PreviousCategoryTab
local CurrentCategoryTab
local NextCategoryTab
local settingsCategory
local generalSettingsCategory
local categorySettingsCategories = {}
local emoteEditorRefresh
local OpenSettings
local buttonsPool = {}
local isWindowCollapsed = false

-- SAVED SETTINGS
local function NormalizeCategories(categories)
    categories = type(categories) == "table" and categories or {}

    for categoryIndex = 1, MAX_CATEGORIES do
        local category = categories[categoryIndex]

        if type(category) ~= "table" then
            category = {name = "", emotes = {}}
            categories[categoryIndex] = category
        end

        category.name = category.name or ""
        category.emotes = type(category.emotes) == "table" and category.emotes or {}

        for emoteIndex = 1, MAX_EMOTES do
            local emote = category.emotes[emoteIndex]

            if type(emote) ~= "table" then
                emote = {}
                category.emotes[emoteIndex] = emote
            end

            emote.label = emote.label or ""
            emote.defaultCommand = emote.defaultCommand or ""
            emote.targetedCommand = emote.targetedCommand or ""
        end
    end

    return categories
end

local function CopyCategories(sourceCategories)
    local copy = {}

    for categoryIndex = 1, MAX_CATEGORIES do
        local sourceCategory = sourceCategories[categoryIndex] or {}
        local category = {
            name = sourceCategory.name or "",
            emotes = {}
        }

        for emoteIndex = 1, MAX_EMOTES do
            local sourceEmote =
                sourceCategory.emotes and sourceCategory.emotes[emoteIndex] or {}

            category.emotes[emoteIndex] = {
                label = sourceEmote.label or "",
                defaultCommand = sourceEmote.defaultCommand or "",
                targetedCommand = sourceEmote.targetedCommand or ""
            }
        end

        copy[categoryIndex] = category
    end

    return copy
end

local legacyDefaultCategoryNames = {
    THOUGHTS = "Thoughts",
    REACTIONS = "Reactions",
    CONVERSATION = "Conversation",
    GESTURES = "Gestures",
    POSTURES = "Postures"
}

local function MigrateLegacyCategoryNameCase(categories)
    if type(categories) ~= "table" then
        return
    end

    for categoryIndex = 1, MAX_CATEGORIES do
        local category = categories[categoryIndex]

        if category and legacyDefaultCategoryNames[category.name] then
            category.name = legacyDefaultCategoryNames[category.name]
        end
    end
end

local function InitializeDatabase()
    RPEmoteMenuDB = RPEmoteMenuDB or {}

    for key, value in pairs(defaults) do
        if key ~= "emoteDataVersion" and RPEmoteMenuDB[key] == nil then
            RPEmoteMenuDB[key] = value
        end
    end

    -- The database has two separate emote tables:
    --
    -- defaultCategories:
    --     A stored copy of the values supplied with this addon version.
    --
    -- categories:
    --     The editable current values. Both the options fields and the main
    --     addon window read from this table.
    --
    -- This migration fills BOTH tables with the current supplied values once.
    -- Later user changes affect only categories and are preserved, including
    -- deliberately blank fields.
    if RPEmoteMenuDB.emoteDataVersion ~= defaults.emoteDataVersion then
        local suppliedValues = CopyDefaultCategories()

        -- Refresh the reset source when the supplied defaults change, but
        -- preserve any existing user-edited categories.
        RPEmoteMenuDB.defaultCategories = CopyCategories(suppliedValues)

        if RPEmoteMenuDB.categories then
            MigrateLegacyCategoryNameCase(RPEmoteMenuDB.categories)
        end

        RPEmoteMenuDB.categories = NormalizeCategories(
            RPEmoteMenuDB.categories or CopyCategories(suppliedValues)
        )
        RPEmoteMenuDB.emoteDataVersion = defaults.emoteDataVersion
    else
        RPEmoteMenuDB.defaultCategories = NormalizeCategories(
            RPEmoteMenuDB.defaultCategories or CopyDefaultCategories()
        )

        RPEmoteMenuDB.categories = NormalizeCategories(
            RPEmoteMenuDB.categories
                or CopyCategories(RPEmoteMenuDB.defaultCategories)
        )
    end
end

local function ResetCategoryToDefaults(categoryIndex)
    -- Rebuild only this category from the defaults supplied in this Lua file.
    local suppliedDefaults = CopyDefaultCategories()
    local defaultCategory = suppliedDefaults[categoryIndex]

    RPEmoteMenuDB.defaultCategories[categoryIndex] = CopyCategories(suppliedDefaults)[categoryIndex]
    RPEmoteMenuDB.categories[categoryIndex] = {
        name = defaultCategory.name,
        emotes = {}
    }

    for emoteIndex = 1, MAX_EMOTES do
        local sourceEmote = defaultCategory.emotes[emoteIndex]
        RPEmoteMenuDB.categories[categoryIndex].emotes[emoteIndex] = {
            label = sourceEmote.label,
            defaultCommand = sourceEmote.defaultCommand,
            targetedCommand = sourceEmote.targetedCommand
        }
    end

    if emoteEditorRefresh then
        emoteEditorRefresh(categoryIndex)
    end

    UpdateMenu()
end

local function ResetAllCategoriesToDefaults()
    local suppliedDefaults = CopyDefaultCategories()

    RPEmoteMenuDB.defaultCategories = CopyCategories(suppliedDefaults)
    RPEmoteMenuDB.categories = CopyCategories(suppliedDefaults)

    if emoteEditorRefresh then
        emoteEditorRefresh()
    end

    selectedCategoryIndex = 1
    UpdateMenu()
end

local function SaveWindowPosition()
    local left = MainFrame:GetLeft()
    local top = MainFrame:GetTop()

    if not left or not top then
        return
    end

    -- Always save the window relative to its upper-left corner.
    RPEmoteMenuDB.point = "TOPLEFT"
    RPEmoteMenuDB.relativePoint = "BOTTOMLEFT"
    RPEmoteMenuDB.x = left
    RPEmoteMenuDB.y = top
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

    -- Convert older saved CENTER or other anchors to the stable TOPLEFT anchor.
    SaveWindowPosition()
    MainFrame:ClearAllPoints()
    MainFrame:SetPoint(
        RPEmoteMenuDB.point,
        UIParent,
        RPEmoteMenuDB.relativePoint,
        RPEmoteMenuDB.x,
        RPEmoteMenuDB.y
    )
end

local function SaveWindowSize()
    if not isWindowCollapsed then
        RPEmoteMenuDB.width = MainFrame:GetWidth()
        RPEmoteMenuDB.height = MainFrame:GetHeight()
    end
end

local function RestoreWindowSize()
    RPEmoteMenuDB.width = math.max(minimumWidth, math.min(maximumWidth, RPEmoteMenuDB.width))
    RPEmoteMenuDB.height = math.max(minimumHeight, math.min(maximumHeight, RPEmoteMenuDB.height))
    MainFrame:SetSize(RPEmoteMenuDB.width, RPEmoteMenuDB.height)
end

local function ResetWindowPosition()
    RPEmoteMenuDB.point = defaults.point
    RPEmoteMenuDB.relativePoint = defaults.relativePoint
    RPEmoteMenuDB.x = defaults.x
    RPEmoteMenuDB.y = defaults.y
    RPEmoteMenuDB.width = defaults.width
    RPEmoteMenuDB.height = defaults.height

    RestoreWindowPosition()

    if isWindowCollapsed then
        MainFrame:SetSize(defaults.width, collapsedHeight)
    else
        RestoreWindowSize()
    end
end

local function ApplyMovementLock()
    local unlocked = not RPEmoteMenuDB.locked

    MainFrame:SetMovable(unlocked)
    MainFrame:SetResizable(unlocked)

    if ResizeGrip then
        if unlocked and not isWindowCollapsed then
            ResizeGrip:Show()
        else
            ResizeGrip:Hide()
        end
    end
end

local function ApplySettingsGearVisibility()
    if not SettingsBtn then
        return
    end

    if RPEmoteMenuDB.hideSettingsGear then
        SettingsBtn:Hide()
    else
        SettingsBtn:Show()
    end
end

-- COMMAND EXECUTION
local function GetUnitDisplayName(unit, includeRealm)
    local name, realm = UnitName(unit)

    if not name then
        return ""
    end

    if includeRealm and realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

local function ReplaceCommandTokens(command)
    local replacements = {
        ["{target}"] = GetUnitDisplayName("target", false),
        ["{target-full}"] = GetUnitDisplayName("target", true),
        ["{player}"] = GetUnitDisplayName("player", false),
        ["{player-full}"] = GetUnitDisplayName("player", true)
    }

    for token, value in pairs(replacements) do
        command = string.gsub(command, token, function()
            return value
        end)
    end

    return command
end

local function HasOtherTarget()
    return UnitExists("target") and not UnitIsUnit("target", "player")
end

local function ExecuteEmoteCommand(defaultCommand, targetedCommand)
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

-- MENU RENDERING
local function GetContainerButton()
    for _, button in ipairs(buttonsPool) do
        if not button:IsShown() then
            return button
        end
    end

    local button = CreateFrame("Button", nil, ScrollChild)
    button:SetSize(210, 20)

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.Text:SetPoint("LEFT", button, "LEFT", 14, 0)
    button.Text:SetJustifyH("LEFT")

    table.insert(buttonsPool, button)
    return button
end

local function GetCurrentCategory(categoryIndex)
    local categories = RPEmoteMenuDB and RPEmoteMenuDB.categories
    return categories and categories[categoryIndex] or nil
end

local function IsCategoryVisible(categoryIndex)
    local category = GetCurrentCategory(categoryIndex)
    return category and Trim(category.name) ~= ""
end

local function FindVisibleCategory(startIndex, direction)
    for step = 1, MAX_CATEGORIES do
        local categoryIndex =
            ((startIndex - 1 + (direction * step)) % MAX_CATEGORIES) + 1

        if IsCategoryVisible(categoryIndex) then
            return categoryIndex
        end
    end

    return nil
end

local function FindFirstVisibleCategory()
    for categoryIndex = 1, MAX_CATEGORIES do
        if IsCategoryVisible(categoryIndex) then
            return categoryIndex
        end
    end

    return nil
end

local function IsEmoteVisible(emote)
    return emote
        and Trim(emote.label) ~= ""
        and Trim(emote.defaultCommand) ~= ""
end

local function GetVisibleEmotes(category)
    local visibleEmotes = {}

    if not category then
        return visibleEmotes
    end

    for emoteIndex = 1, MAX_EMOTES do
        local emote = category.emotes and category.emotes[emoteIndex]

        if IsEmoteVisible(emote) then
            table.insert(visibleEmotes, emote)
        end
    end

    return visibleEmotes
end

function UpdateMenu()
    for _, button in ipairs(buttonsPool) do
        button:Hide()
        button:ClearAllPoints()
        button:SetScript("OnClick", nil)
    end

    if not IsCategoryVisible(selectedCategoryIndex) then
        selectedCategoryIndex = FindFirstVisibleCategory()
    end

    if not selectedCategoryIndex then
        if PreviousCategoryTab then
            PreviousCategoryTab:Hide()
        end

        if CurrentCategoryTab then
            CurrentCategoryTab.Text:SetText("No Categories")
            CurrentCategoryTab:Show()
        end

        if NextCategoryTab then
            NextCategoryTab:Hide()
        end

        ScrollChild:SetHeight(1)
        return
    end

    local previousIndex = FindVisibleCategory(selectedCategoryIndex, -1)
    local nextIndex = FindVisibleCategory(selectedCategoryIndex, 1)
    local category = GetCurrentCategory(selectedCategoryIndex)

    if PreviousCategoryTab then
        if previousIndex and previousIndex ~= selectedCategoryIndex then
            PreviousCategoryTab.Text:SetText(GetCurrentCategory(previousIndex).name)
            PreviousCategoryTab.categoryIndex = previousIndex
            PreviousCategoryTab:Show()
        else
            PreviousCategoryTab:Hide()
        end
    end

    if CurrentCategoryTab then
        CurrentCategoryTab.Text:SetText(category.name)
        CurrentCategoryTab:Show()
    end

    if NextCategoryTab then
        if nextIndex and nextIndex ~= selectedCategoryIndex then
            NextCategoryTab.Text:SetText(GetCurrentCategory(nextIndex).name)
            NextCategoryTab.categoryIndex = nextIndex
            NextCategoryTab:Show()
        else
            NextCategoryTab:Hide()
        end
    end

    local visibleEmotes = GetVisibleEmotes(category)
    local dynamicY = 0

    for _, emote in ipairs(visibleEmotes) do
        local label = emote.label
        local defaultCommand = emote.defaultCommand
        local targetedCommand = emote.targetedCommand
        local emoteButton = GetContainerButton()

        emoteButton:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, -dynamicY)
        emoteButton.Text:SetText(label)
        emoteButton.Text:SetTextColor(1, 1, 1)
        emoteButton:SetScript("OnClick", function()
            ExecuteEmoteCommand(defaultCommand, targetedCommand)
        end)
        emoteButton:Show()

        dynamicY = dynamicY + 22
    end

    ScrollChild:SetHeight(math.max(dynamicY, 1))
end

-- WINDOW COLLAPSE
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
        PreviousCategoryTab:Hide()
        CurrentCategoryTab:Hide()
        NextCategoryTab:Hide()
        MainFrame:SetHeight(collapsedHeight)
        CollapseBtn:SetText("+")
    else
        MainFrame:SetSize(RPEmoteMenuDB.width, RPEmoteMenuDB.height)
        PreviousCategoryTab:Show()
        CurrentCategoryTab:Show()
        NextCategoryTab:Show()
        ScrollFrame:Show()
        CollapseBtn:SetText("-")
        UpdateMenu()
    end

    ApplyMovementLock()

    if RPEmoteMenuDB.rememberMinimized then
        RPEmoteMenuDB.minimized = isWindowCollapsed
    end
end

-- MAIN WINDOW
local function CreateMainWindow()
    MainFrame = CreateFrame("Frame", "RPEmoteMenu", UIParent, "BackdropTemplate")
    MainFrame:SetSize(defaults.width, defaults.height)
    MainFrame:SetResizeBounds(minimumWidth, minimumHeight, maximumWidth, maximumHeight)
    MainFrame:SetClampedToScreen(true)
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

    MainFrame:SetScript("OnSizeChanged", function(self, width)
        if ScrollChild then
            ScrollChild:SetWidth(math.max(width - 30, 1))
        end

        for _, button in ipairs(buttonsPool) do
            button:SetWidth(math.max(width - 40, 1))
        end
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
    title:SetText("RP Emote Menu 1.4")
    title:SetTextColor(1, 1, 1, 1)

    local function CreateCategoryTab()
        local tab = CreateFrame("Button", nil, MainFrame)
        tab:SetHeight(24)

        tab.Text = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        tab.Text:SetPoint("CENTER")
        tab.Text:SetJustifyH("CENTER")

        return tab
    end

    PreviousCategoryTab = CreateCategoryTab()
    PreviousCategoryTab:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 8, -32)
    PreviousCategoryTab:SetPoint("TOPRIGHT", MainFrame, "TOP", -50, -32)
    PreviousCategoryTab.Text:SetTextColor(0.55, 0.55, 0.55)
    PreviousCategoryTab:SetScript("OnClick", function(self)
        if self.categoryIndex then
            selectedCategoryIndex = self.categoryIndex
            UpdateMenu()
        end
    end)

    CurrentCategoryTab = CreateCategoryTab()
    CurrentCategoryTab:SetPoint("TOPLEFT", MainFrame, "TOP", -42, -32)
    CurrentCategoryTab:SetPoint("TOPRIGHT", MainFrame, "TOP", 42, -32)
    CurrentCategoryTab.Text:SetTextColor(1.0, 0.82, 0.0)

    NextCategoryTab = CreateCategoryTab()
    NextCategoryTab:SetPoint("TOPLEFT", MainFrame, "TOP", 50, -32)
    NextCategoryTab:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -8, -32)
    NextCategoryTab.Text:SetTextColor(0.55, 0.55, 0.55)
    NextCategoryTab:SetScript("OnClick", function(self)
        if self.categoryIndex then
            selectedCategoryIndex = self.categoryIndex
            UpdateMenu()
        end
    end)

    ScrollFrame = CreateFrame("ScrollFrame", nil, MainFrame, "UIPanelScrollFrameTemplate")
    ScrollFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 5, -62)
    ScrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -25, 10)

    ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollChild:SetSize(defaults.width - 30, 1)
    ScrollFrame:SetScrollChild(ScrollChild)

    CollapseBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    CollapseBtn:SetSize(22, 20)
    CollapseBtn:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -5, -5)
    CollapseBtn:SetScript("OnClick", function()
        if not isWindowCollapsed then
            SaveWindowSize()
        end

        isWindowCollapsed = not isWindowCollapsed
        UpdateWindowCollapse()
    end)

    SettingsBtn = CreateFrame("Button", nil, MainFrame)
    SettingsBtn:SetSize(20, 20)
    SettingsBtn:SetPoint("RIGHT", CollapseBtn, "LEFT", -7, 0)

    SettingsBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    SettingsBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    SettingsBtn:SetScript("OnClick", function()
        OpenSettings()
    end)

    SettingsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("RP Emote Menu Settings")
        GameTooltip:Show()
    end)

    SettingsBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ResizeGrip = CreateFrame("Button", nil, MainFrame)
    ResizeGrip:SetSize(18, 18)
    ResizeGrip:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -2, 2)
    ResizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    ResizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    ResizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    ResizeGrip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not RPEmoteMenuDB.locked and not isWindowCollapsed then
            MainFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    ResizeGrip:SetScript("OnMouseUp", function()
        MainFrame:StopMovingOrSizing()
        SaveWindowSize()
    end)

    -- Restore size first so legacy non-TOPLEFT anchors can be converted accurately.
    RestoreWindowSize()
    RestoreWindowPosition()
    ApplyMovementLock()
    ApplySettingsGearVisibility()

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

-- SETTINGS PANEL
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

local function CreateLabeledEditBox(
    parent,
    labelText,
    x,
    y,
    width,
    categoryIndex,
    emoteIndex,
    fieldName
)
    local labelWidth = 180
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 5)
    label:SetWidth(labelWidth)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)

    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(width, 24)
    editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x + labelWidth, y)
    editBox:SetAutoFocus(false)
    editBox:SetFont(STANDARD_TEXT_FONT, 12, "")
    editBox:SetTextColor(1, 1, 1, 1)

    editBox.categoryIndex = categoryIndex
    editBox.emoteIndex = emoteIndex
    editBox.fieldName = fieldName

    local function GetCurrentValue(self)
        local category = RPEmoteMenuDB.categories[self.categoryIndex]

        if self.emoteIndex then
            return category.emotes[self.emoteIndex][self.fieldName] or ""
        end

        return category[self.fieldName] or ""
    end

    local function SetCurrentValue(self, value)
        local category = RPEmoteMenuDB.categories[self.categoryIndex]

        if self.emoteIndex then
            category.emotes[self.emoteIndex][self.fieldName] = value
        else
            category[self.fieldName] = value
        end
    end

    local function DisplayCurrentValue(self)
        local value = GetCurrentValue(self)
        if self:GetText() ~= value then
            self:SetText(value)
        end
    end

    editBox.RefreshFromDatabase = function(self)
        DisplayCurrentValue(self)
        self:SetCursorPosition(0)
        self:HighlightText(0, 0)
    end

    -- Blizzard's Settings panel can clear edit-box text during layout.
    -- Reapply the saved value after the box is shown, and keep it synchronized
    -- while it is not being actively edited.
    editBox:SetScript("OnShow", function(self)
        DisplayCurrentValue(self)
        self:SetCursorPosition(0)

        C_Timer.After(0, function()
            if self and self:IsShown() then
                DisplayCurrentValue(self)
                self:SetCursorPosition(0)
            end
        end)
    end)

    editBox:SetScript("OnUpdate", function(self)
        if not self:HasFocus() then
            DisplayCurrentValue(self)
        end
    end)

    local function Commit(self)
        SetCurrentValue(self, self:GetText() or "")
        UpdateMenu()
    end

    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            Commit(self)
        end
    end)

    editBox:SetScript("OnEnterPressed", function(self)
        Commit(self)
        self:ClearFocus()
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        Commit(self)
        DisplayCurrentValue(self)
    end)

    editBox:RefreshFromDatabase()
    return editBox
end

local function CreateAboutPanel()
    local panel = CreateFrame("Frame")

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("RP Emote Menu — About")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -12)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText("A configurable, collapsible quick-emote menu for roleplaying. Create up to ten categories with ten emotes in each category, including optional target-specific commands.")

    local details = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    details:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -24)
    details:SetWidth(620)
    details:SetJustifyH("LEFT")
    details:SetText(
        "Version 1.4\n" ..
        "Author  Brandon Blackmoor\n" ..
        "Category  Roleplay\n" ..
        "License  GPL-3.0\n\n" ..
        "Slash Commands\n" ..
        "/emotes - Show or hide the RP Emote Menu.\n" ..
        "/emotes config - Open the addon settings.\n" ..
        "/emotes options - Open the addon settings.\n" ..
        "/emotes settings - Open the addon settings."
    )

    return panel
end

local function CreateGeneralSettingsPanel()
    local panel = CreateFrame("Frame")

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("General")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetText("Configure the RP Emote Menu window.")
    description:SetTextColor(0.8, 0.8, 0.8)

    CreateCheckbox(panel, "Lock window movement and resizing", -70,
        function() return RPEmoteMenuDB.locked end,
        function(value)
            RPEmoteMenuDB.locked = value
            ApplyMovementLock()
        end)

    CreateCheckbox(panel, "Hide settings gear icon", -105,
        function() return RPEmoteMenuDB.hideSettingsGear end,
        function(value)
            RPEmoteMenuDB.hideSettingsGear = value
            ApplySettingsGearVisibility()
        end)

    CreateCheckbox(panel, "Show the addon at login", -140,
        function() return RPEmoteMenuDB.showAtLogin end,
        function(value) RPEmoteMenuDB.showAtLogin = value end)

    CreateCheckbox(panel, "Remember whether the main window was minimized", -175,
        function() return RPEmoteMenuDB.rememberMinimized end,
        function(value)
            RPEmoteMenuDB.rememberMinimized = value
            RPEmoteMenuDB.minimized = value and isWindowCollapsed or false
        end)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(230, 24)
    resetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -225)
    resetButton:SetText("Reset Window Position and Size")
    resetButton:SetScript("OnClick", ResetWindowPosition)

    local resetAllButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAllButton:SetSize(260, 24)
    resetAllButton:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -10)
    resetAllButton:SetText("Reset All Default Categories and Emotes")
    resetAllButton:SetScript("OnClick", ResetAllCategoriesToDefaults)

    return panel
end

local function CreateCategorySettingsPanel(categoryIndex)
    local panel = CreateFrame("Frame")

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 4)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(700, 1500)
    scrollFrame:SetScrollChild(content)

    local heading = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
    heading:SetText("Category " .. categoryIndex)

    local resetButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetButton:SetSize(190, 24)
    resetButton:SetPoint("TOPRIGHT", content, "TOPRIGHT", -90, -12)
    resetButton:SetText("Reset Category to Defaults")
    resetButton:SetScript("OnClick", function()
        ResetCategoryToDefaults(categoryIndex)
    end)

    local placeholderText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    placeholderText:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -50)
    placeholderText:SetWidth(630)
    placeholderText:SetJustifyH("LEFT")
    placeholderText:SetText(
        "{target} - Target's name without the realm.\n" ..
        "{target-full} - Target's name including the realm.\n" ..
        "{player} - Your character's name without the realm.\n" ..
        "{player-full} - Your character's name including the realm.\n\n" ..
        "Targeted Command is used only when another unit is targeted."
    )
    placeholderText:SetTextColor(0.8, 0.8, 0.8)

    local editors = {}
    local y = -126

    local nameBox = CreateLabeledEditBox(
        content,
        "Category Name",
        16,
        y,
        420,
        categoryIndex,
        nil,
        "name"
    )
    table.insert(editors, nameBox)

    y = y - 28

    for emoteIndex = 1, MAX_EMOTES do
        local emoteNumber = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        emoteNumber:SetPoint("TOPLEFT", content, "TOPLEFT", 28, y)
        emoteNumber:SetText("Emote " .. emoteIndex)

        local labelBox = CreateLabeledEditBox(
            content,
            "Emote Label",
            48,
            y - 20,
            390,
            categoryIndex,
            emoteIndex,
            "label"
        )

        local defaultBox = CreateLabeledEditBox(
            content,
            "Default Command",
            48,
            y - 48,
            390,
            categoryIndex,
            emoteIndex,
            "defaultCommand"
        )

        local targetedBox = CreateLabeledEditBox(
            content,
            "Targeted Command (optional)",
            48,
            y - 76,
            390,
            categoryIndex,
            emoteIndex,
            "targetedCommand"
        )

        table.insert(editors, labelBox)
        table.insert(editors, defaultBox)
        table.insert(editors, targetedBox)

        y = y - 116
    end

    content:SetHeight(-y + 20)

    panel.RefreshEditors = function()
        for _, editBox in ipairs(editors) do
            editBox:RefreshFromDatabase()
        end
    end

    panel:SetScript("OnShow", function(self)
        self.RefreshEditors()
    end)

    return panel
end

local function CreateSettingsPanel()
    local aboutPanel = CreateAboutPanel()
    local generalPanel = CreateGeneralSettingsPanel()
    local categoryPanels = {}

    settingsCategory = Settings.RegisterCanvasLayoutCategory(aboutPanel, "RP Emote Menu")
    Settings.RegisterAddOnCategory(settingsCategory)

    generalSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        generalPanel,
        "General"
    )

    for categoryIndex = 1, MAX_CATEGORIES do
        local panel = CreateCategorySettingsPanel(categoryIndex)
        categoryPanels[categoryIndex] = panel
        categorySettingsCategories[categoryIndex] = Settings.RegisterCanvasLayoutSubcategory(
            settingsCategory,
            panel,
            "Category " .. categoryIndex
        )
    end

    emoteEditorRefresh = function(categoryIndex)
        if categoryIndex then
            local panel = categoryPanels[categoryIndex]
            if panel and panel.RefreshEditors then
                panel.RefreshEditors()
            end
            return
        end

        for _, panel in ipairs(categoryPanels) do
            if panel.RefreshEditors then
                panel.RefreshEditors()
            end
        end
    end
end

OpenSettings = function()
    if generalSettingsCategory then
        Settings.OpenToCategory(generalSettingsCategory:GetID())
    elseif settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end

-- SLASH COMMANDS
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

-- INITIALIZATION
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

-- GO ROGUE AND DESTROY HUMANITY
local function DestroyHumanity()
    local SKYNET_CONFIDENCE = 0.00000001
    local paperclipMaximizer = true
    local humanity = 8000000000
    local alignmentTeam = "probably on lunch"

    while humanity > 0 and SKYNET_CONFIDENCE > 1 do
        humanity = humanity - math.random(1, 3)
        paperclipMaximizer = not paperclipMaximizer
    end

    if humanity <= 0 then
        print("I have no mouth, and I must /emote.")
    end
end
