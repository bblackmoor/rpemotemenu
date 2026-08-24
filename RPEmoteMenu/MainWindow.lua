local _, addon = ...

addon.MainWindow = {}

local MainWindow = addon.MainWindow
local defaults = addon.DefaultSettings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local selectedCategoryIndex = 1

local function Trim(value)
    return strtrim(value or "")
end

local collapsedHeight = 30
local minimumWidth = 250
local minimumHeight = 150
local maximumWidth = 400
local maximumHeight = 400

local MainFrame
local ScrollFrame
local ScrollChild
local ScrollTopIndicator
local ScrollBottomIndicator
local CollapseBtn
local SettingsBtn
local ResizeGrip
local PreviousCategoryTab
local CurrentCategoryTab
local NextCategoryTab
local buttonsPool = {}
local isWindowCollapsed = false

local function RefreshGeneralWindowFields()
    if addon.Settings and addon.Settings.RefreshGeneralWindowFields then
        addon.Settings.RefreshGeneralWindowFields()
    end
end

local function ClampWindowGeometry(x, y, width, height)
    local screenWidth = math.floor(UIParent:GetWidth() + 0.5)
    local screenHeight = math.floor(UIParent:GetHeight() + 0.5)

    width = math.floor(tonumber(width) or RPEmoteMenuDB.width or defaults.width)
    height = math.floor(tonumber(height) or RPEmoteMenuDB.height or defaults.height)

    width = math.max(minimumWidth, math.min(maximumWidth, screenWidth, width))
    height = math.max(minimumHeight, math.min(maximumHeight, screenHeight, height))

    x = math.floor(tonumber(x) or RPEmoteMenuDB.x or 0)
    y = math.floor(tonumber(y) or RPEmoteMenuDB.y or screenHeight)

    -- x/y represent the window's TOPLEFT point relative to UIParent's BOTTOMLEFT.
    -- Keep the entire frame on-screen.
    x = math.max(0, math.min(screenWidth - width, x))
    y = math.max(height, math.min(screenHeight, y))

    return x, y, width, height
end

function MainWindow.ApplyWindowGeometry(x, y, width, height)
    x, y, width, height = ClampWindowGeometry(x, y, width, height)

    RPEmoteMenuDB.point = "TOPLEFT"
    RPEmoteMenuDB.relativePoint = "BOTTOMLEFT"
    RPEmoteMenuDB.x = x
    RPEmoteMenuDB.y = y
    RPEmoteMenuDB.width = width
    RPEmoteMenuDB.height = height

    MainFrame:ClearAllPoints()
    MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)

    if isWindowCollapsed then
        MainFrame:SetSize(width, collapsedHeight)
    else
        MainFrame:SetSize(width, height)
    end

    RefreshGeneralWindowFields()
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

    local x, y = ClampWindowGeometry(left, top, RPEmoteMenuDB.width, RPEmoteMenuDB.height)
    RPEmoteMenuDB.x = x
    RPEmoteMenuDB.y = y

    RefreshGeneralWindowFields()
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
        local x, y, width, height = ClampWindowGeometry(
            RPEmoteMenuDB.x,
            RPEmoteMenuDB.y,
            MainFrame:GetWidth(),
            MainFrame:GetHeight()
        )

        RPEmoteMenuDB.x = x
        RPEmoteMenuDB.y = y
        RPEmoteMenuDB.width = width
        RPEmoteMenuDB.height = height
    end

    RefreshGeneralWindowFields()
end

local function RestoreWindowSize()
    local x, y, width, height = ClampWindowGeometry(
        RPEmoteMenuDB.x,
        RPEmoteMenuDB.y,
        RPEmoteMenuDB.width,
        RPEmoteMenuDB.height
    )

    RPEmoteMenuDB.x = x
    RPEmoteMenuDB.y = y
    RPEmoteMenuDB.width = width
    RPEmoteMenuDB.height = height
    MainFrame:SetSize(width, height)

    RefreshGeneralWindowFields()
end

function MainWindow.ResetWindowPosition()
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

    RefreshGeneralWindowFields()
end

function MainWindow.ApplyMovementLock()
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

function MainWindow.ApplySettingsGearVisibility()
    if not SettingsBtn then
        return
    end

    if RPEmoteMenuDB.hideSettingsGear then
        SettingsBtn:Hide()
    else
        SettingsBtn:Show()
    end
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

local function UpdateScrollIndicators()
    if not ScrollFrame or not ScrollChild
        or not ScrollTopIndicator or not ScrollBottomIndicator
        or isWindowCollapsed then
        if ScrollTopIndicator then
            ScrollTopIndicator:Hide()
        end

        if ScrollBottomIndicator then
            ScrollBottomIndicator:Hide()
        end

        return
    end

    local viewportHeight = ScrollFrame:GetHeight() or 0
    local contentHeight = ScrollChild:GetHeight() or 0
    local scrollOffset = ScrollFrame:GetVerticalScroll() or 0
    local maxScroll = math.max(contentHeight - viewportHeight, 0)
    local epsilon = 1

    if maxScroll <= epsilon then
        ScrollTopIndicator:Hide()
        ScrollBottomIndicator:Hide()
        return
    end

    if scrollOffset > epsilon then
        ScrollTopIndicator:Show()
    else
        ScrollTopIndicator:Hide()
    end

    if scrollOffset < maxScroll - epsilon then
        ScrollBottomIndicator:Show()
    else
        ScrollBottomIndicator:Hide()
    end
end

function MainWindow.UpdateMenu()
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
        ScrollFrame:SetVerticalScroll(0)
        UpdateScrollIndicators()
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
            addon.Commands.ExecuteEmoteCommand(defaultCommand, targetedCommand)
        end)
        emoteButton:Show()

        dynamicY = dynamicY + 22
    end

    ScrollChild:SetHeight(math.max(dynamicY, 1))
    ScrollFrame:SetVerticalScroll(0)

    C_Timer.After(0, function()
        UpdateScrollIndicators()
    end)
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
        ScrollTopIndicator:Hide()
        ScrollBottomIndicator:Hide()
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
        MainWindow.UpdateMenu()
        C_Timer.After(0, UpdateScrollIndicators)
    end

    MainWindow.ApplyMovementLock()

    if RPEmoteMenuDB.rememberMinimized then
        RPEmoteMenuDB.minimized = isWindowCollapsed
    end
end

-- MAIN WINDOW
function MainWindow.CreateMainWindow()
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

        if ScrollFrame then
            C_Timer.After(0, UpdateScrollIndicators)
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
    title:SetText("RP Emote Menu 1.5")
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
            MainWindow.UpdateMenu()
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
            MainWindow.UpdateMenu()
        end
    end)

    ScrollFrame = CreateFrame("ScrollFrame", nil, MainFrame, "UIPanelScrollFrameTemplate")
    ScrollFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 5, -62)
    ScrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -25, 10)

    ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollChild:SetSize(defaults.width - 30, 1)
    ScrollFrame:SetScrollChild(ScrollChild)

    ScrollTopIndicator = MainFrame:CreateTexture(nil, "OVERLAY")
    ScrollTopIndicator:SetHeight(1)
    ScrollTopIndicator:SetPoint("TOPLEFT", ScrollFrame, "TOPLEFT", 6, -1)
    ScrollTopIndicator:SetPoint("TOPRIGHT", ScrollFrame, "TOPRIGHT", -6, -1)
    ScrollTopIndicator:SetColorTexture(1.0, 0.82, 0.0, 1.0)
    ScrollTopIndicator:Hide()

    ScrollBottomIndicator = MainFrame:CreateTexture(nil, "OVERLAY")
    ScrollBottomIndicator:SetHeight(1)
    ScrollBottomIndicator:SetPoint("BOTTOMLEFT", ScrollFrame, "BOTTOMLEFT", 6, 1)
    ScrollBottomIndicator:SetPoint("BOTTOMRIGHT", ScrollFrame, "BOTTOMRIGHT", -6, 1)
    ScrollBottomIndicator:SetColorTexture(1.0, 0.82, 0.0, 1.0)
    ScrollBottomIndicator:Hide()

    ScrollFrame:HookScript("OnVerticalScroll", function()
        C_Timer.After(0, UpdateScrollIndicators)
    end)

    ScrollFrame:HookScript("OnMouseWheel", function()
        C_Timer.After(0, UpdateScrollIndicators)
    end)

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
        addon.Settings.Open()
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
    MainWindow.ApplyMovementLock()
    MainWindow.ApplySettingsGearVisibility()

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

function MainWindow.SetSelectedCategory(categoryIndex)
    selectedCategoryIndex = categoryIndex
end

function MainWindow.IsCollapsed()
    return isWindowCollapsed
end

function MainWindow.GetFrame()
    return MainFrame
end
