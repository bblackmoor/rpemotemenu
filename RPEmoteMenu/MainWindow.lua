local _, addon = ...

addon.MainWindow = {}

local MainWindow = addon.MainWindow
local Database = addon.Database
local defaults = addon.DefaultSettings
local settings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local selectedCategoryIndex = 1

local function Trim(value)
    return strtrim(value or "")
end

local collapsedHeight = 30
local minimumWidth = 250
local minimumHeight = 150
local maximumWidth = 600
local maximumHeight = 600
local sidebarWidth = defaults.sidebarWidth
local minimumSidebarWidth = addon.MIN_SIDEBAR_WIDTH
local maximumSidebarWidth = addon.MAX_SIDEBAR_WIDTH
local minimumEmoteColumnWidth = 45
local categoryButtonHeight = 24
local emoteButtonHeight = 20

local MainFrame
local CategorySidebar
local CategoryScrollFrame
local CategoryScrollChild
local CategoryEmptyLabel
local SidebarDivider
local ScrollFrame
local ScrollChild
local ScrollTopIndicator
local ScrollBottomIndicator
local CollapseBtn
local SettingsBtn
local ResizeGrip
local categoryButtons = {}
local buttonsPool = {}
local isWindowCollapsed = false
local fadeGeneration = 0
local opacityAnimationGroup
local opacityAnimation
local opacityAnimationTarget
local fadeOutDuration = 0.5
local fadeInDuration = 0.2

local function RefreshGeneralWindowFields()
    if addon.Settings and addon.Settings.RefreshGeneralWindowFields then
        addon.Settings.RefreshGeneralWindowFields()
    end
end

local function GetMaximumSidebarWidth(windowWidth)
    return math.max(
        minimumSidebarWidth,
        math.min(
            maximumSidebarWidth,
            math.floor(windowWidth) - 35 - minimumEmoteColumnWidth
        )
    )
end

local function ClampWindowGeometry(x, y, width, height)
    local screenWidth = math.floor(UIParent:GetWidth() + 0.5)
    local screenHeight = math.floor(UIParent:GetHeight() + 0.5)

    width = math.floor(tonumber(width) or settings.width or defaults.width)
    height = math.floor(tonumber(height) or settings.height or defaults.height)

    width = math.max(minimumWidth, math.min(maximumWidth, screenWidth, width))
    height = math.max(minimumHeight, math.min(maximumHeight, screenHeight, height))

    x = math.floor(tonumber(x) or settings.x or 0)
    y = math.floor(tonumber(y) or settings.y or screenHeight)

    -- x/y represent the window's TOPLEFT point relative to UIParent's BOTTOMLEFT.
    -- Keep the entire frame on-screen.
    x = math.max(0, math.min(screenWidth - width, x))
    y = math.max(height, math.min(screenHeight, y))

    return x, y, width, height
end

function MainWindow.ApplyWindowGeometry(x, y, width, height)
    x, y, width, height = ClampWindowGeometry(x, y, width, height)

    settings.point = "TOPLEFT"
    settings.relativePoint = "BOTTOMLEFT"
    settings.x = x
    settings.y = y
    settings.width = width
    settings.height = height

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
    settings.point = "TOPLEFT"
    settings.relativePoint = "BOTTOMLEFT"

    local x, y = ClampWindowGeometry(left, top, settings.width, settings.height)
    settings.x = x
    settings.y = y

    RefreshGeneralWindowFields()
end

local function RestoreWindowPosition()
    MainFrame:ClearAllPoints()
    MainFrame:SetPoint(
        settings.point,
        UIParent,
        settings.relativePoint,
        settings.x,
        settings.y
    )

    -- Convert older saved CENTER or other anchors to the stable TOPLEFT anchor.
    SaveWindowPosition()
    MainFrame:ClearAllPoints()
    MainFrame:SetPoint(
        settings.point,
        UIParent,
        settings.relativePoint,
        settings.x,
        settings.y
    )
end

local function SaveWindowSize()
    if not isWindowCollapsed then
        local x, y, width, height = ClampWindowGeometry(
            settings.x,
            settings.y,
            MainFrame:GetWidth(),
            MainFrame:GetHeight()
        )

        settings.x = x
        settings.y = y
        settings.width = width
        settings.height = height
    end

    RefreshGeneralWindowFields()
end

local function RestoreWindowSize()
    local x, y, width, height = ClampWindowGeometry(
        settings.x,
        settings.y,
        settings.width,
        settings.height
    )

    settings.x = x
    settings.y = y
    settings.width = width
    settings.height = height
    MainFrame:SetSize(width, height)

    RefreshGeneralWindowFields()
end

function MainWindow.ResetWindowPosition()
    settings.point = defaults.point
    settings.relativePoint = defaults.relativePoint
    settings.x = defaults.x
    settings.y = defaults.y
    settings.width = defaults.width
    settings.height = defaults.height
    settings.sidebarWidth = defaults.sidebarWidth

    MainWindow.ApplySidebarWidth(defaults.sidebarWidth)

    RestoreWindowPosition()

    if isWindowCollapsed then
        MainFrame:SetSize(defaults.width, collapsedHeight)
    else
        RestoreWindowSize()
    end

    RefreshGeneralWindowFields()
end

function MainWindow.ApplySidebarWidth(width)
    if not MainFrame or not CategorySidebar or not CategoryScrollChild
        or not ScrollFrame or not ScrollChild then
        return
    end

    local requestedWidth = math.floor(tonumber(width) or defaults.sidebarWidth)
    sidebarWidth = math.max(
        minimumSidebarWidth,
        math.min(GetMaximumSidebarWidth(MainFrame:GetWidth()), requestedWidth)
    )
    settings.sidebarWidth = sidebarWidth

    CategorySidebar:SetWidth(sidebarWidth)
    CategoryScrollChild:SetWidth(sidebarWidth - 7)

    for _, button in ipairs(categoryButtons) do
        button:SetWidth(sidebarWidth - 7)
    end

    ScrollFrame:ClearAllPoints()
    ScrollFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", sidebarWidth + 10, -40)
    ScrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -25, 10)

    local contentWidth = math.max(MainFrame:GetWidth() - sidebarWidth - 35, 1)
    ScrollChild:SetWidth(contentWidth)

    for _, button in ipairs(buttonsPool) do
        button:SetWidth(math.max(contentWidth - 5, 1))
    end

    MainWindow.UpdateMenu()
    RefreshGeneralWindowFields()
end

function MainWindow.ApplyMovementLock()
    local unlocked = not settings.locked

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

    if settings.hideSettingsGear then
        SettingsBtn:Hide()
    else
        SettingsBtn:Show()
    end
end

local function ApplyFont(fontString, fontName, size, color, forceRefresh)
    local _, currentSize, fontFlags = fontString:GetFont()
    local fontFile = addon.GetFontPath(fontName)

    if forceRefresh and currentSize == size then
        local refreshSize = size < 24 and size + 1 or size - 1
        fontString:SetFont(fontFile, refreshSize, fontFlags or "")
    end

    if not fontString:SetFont(fontFile, size, fontFlags or "") then
        fontString:SetFont(STANDARD_TEXT_FONT, size, fontFlags or "")
    end

    fontString:SetTextColor(color.r, color.g, color.b, 1)
end

local function SetWindowOpacity(targetOpacity, duration)
    if not MainFrame then
        return
    end

    local currentOpacity = MainFrame:GetAlpha()

    if opacityAnimationGroup and opacityAnimationGroup:IsPlaying() then
        opacityAnimationGroup:Stop()
    end

    if not duration or math.abs(currentOpacity - targetOpacity) < 0.001 then
        MainFrame:SetAlpha(targetOpacity)
        return
    end

    if not opacityAnimationGroup then
        opacityAnimationGroup = MainFrame:CreateAnimationGroup()
        opacityAnimation = opacityAnimationGroup:CreateAnimation("Alpha")
        opacityAnimation:SetSmoothing("IN_OUT")
        opacityAnimationGroup:SetScript("OnFinished", function()
            MainFrame:SetAlpha(opacityAnimationTarget)
        end)
    end

    MainFrame:SetAlpha(currentOpacity)
    opacityAnimationTarget = targetOpacity
    opacityAnimation:SetFromAlpha(currentOpacity)
    opacityAnimation:SetToAlpha(targetOpacity)
    opacityAnimation:SetDuration(duration)
    opacityAnimationGroup:Play()
end

local function RestoreActiveOpacity(animate)
    fadeGeneration = fadeGeneration + 1

    if MainFrame then
        SetWindowOpacity(
            settings.windowOpacity,
            animate and fadeInDuration or nil
        )
    end
end

local function ScheduleInactiveFade()
    fadeGeneration = fadeGeneration + 1
    local requestedGeneration = fadeGeneration

    if not settings.fadeEnabled or not MainFrame then
        return
    end

    C_Timer.After(settings.fadeDelay, function()
        if requestedGeneration ~= fadeGeneration
            or not settings.fadeEnabled
            or MainFrame:IsMouseOver() then
            return
        end

        SetWindowOpacity(
            math.min(settings.inactiveOpacity, settings.windowOpacity),
            fadeOutDuration
        )
    end)
end

function MainWindow.NotifyActivity()
    RestoreActiveOpacity(true)
end

function MainWindow.ApplyFadeSettings()
    RestoreActiveOpacity()

    if settings.fadeEnabled and MainFrame and not MainFrame:IsMouseOver() then
        ScheduleInactiveFade()
    end
end

function MainWindow.RefreshFont(settingKey, fontName)
    if not MainFrame or settings[settingKey] ~= fontName then
        return
    end

    local buttons
    local fontSize
    local textColor

    if settingKey == "categoryFont" then
        buttons = categoryButtons
        fontSize = settings.categoryFontSize
        textColor = settings.categoryTextColor
    elseif settingKey == "emoteFont" then
        buttons = buttonsPool
        fontSize = settings.emoteFontSize
        textColor = settings.emoteTextColor
    else
        return
    end

    for _, button in ipairs(buttons) do
        local buttonTextColor = textColor

        if settingKey == "categoryFont"
            and button.categoryIndex == selectedCategoryIndex then
            buttonTextColor = settings.selectedCategoryTextColor
        end

        ApplyFont(button.Text, fontName, fontSize, buttonTextColor, true)
    end
end

function MainWindow.ApplyAppearance()
    if not MainFrame then
        return
    end

    local background = settings.backgroundColor
    local border = settings.borderColor
    local backdrop = {
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground"
    }

    if settings.borderStyle == "thin" then
        backdrop.edgeFile = "Interface\\ChatFrame\\ChatFrameBackground"
        backdrop.edgeSize = 1
    elseif settings.borderStyle == "blizzard" then
        backdrop.edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border"
        backdrop.edgeSize = 12
        backdrop.insets = {left = 3, right = 3, top = 3, bottom = 3}
    end

    MainFrame:SetBackdrop(backdrop)
    MainFrame:SetBackdropColor(
        background.r,
        background.g,
        background.b,
        settings.backgroundOpacity
    )
    MainFrame:SetBackdropBorderColor(border.r, border.g, border.b, 1)

    CategorySidebar:SetBackdropColor(
        background.r,
        background.g,
        background.b,
        settings.backgroundOpacity
    )

    if settings.borderStyle == "none" then
        SidebarDivider:Hide()
    else
        SidebarDivider:SetColorTexture(border.r, border.g, border.b, 0.9)
        SidebarDivider:Show()
    end

    categoryButtonHeight = math.max(24, settings.categoryFontSize + 10)
    emoteButtonHeight = math.max(20, settings.emoteFontSize + 8)

    for _, button in ipairs(categoryButtons) do
        button:SetHeight(categoryButtonHeight)
        ApplyFont(
            button.Text,
            settings.categoryFont,
            settings.categoryFontSize,
            settings.categoryTextColor
        )
    end

    for _, button in ipairs(buttonsPool) do
        button:SetHeight(emoteButtonHeight)
        ApplyFont(
            button.Text,
            settings.emoteFont,
            settings.emoteFontSize,
            settings.emoteTextColor
        )
    end

    MainWindow.ApplyFadeSettings()
    MainWindow.UpdateMenu()
end

-- MENU RENDERING
local function GetContainerButton()
    for _, button in ipairs(buttonsPool) do
        if not button:IsShown() then
            return button
        end
    end

    local button = CreateFrame("Button", nil, ScrollChild)
    button:SetSize(math.max(ScrollChild:GetWidth() - 5, 1), emoteButtonHeight)

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.Text:SetPoint("LEFT", button, "LEFT", 7, 0)
    button.Text:SetPoint("RIGHT", button, "RIGHT", -4, 0)
    button.Text:SetJustifyH("LEFT")
    button.Text:SetWordWrap(false)
    ApplyFont(
        button.Text,
        settings.emoteFont,
        settings.emoteFontSize,
        settings.emoteTextColor
    )

    table.insert(buttonsPool, button)
    return button
end

local function GetCurrentCategory(categoryIndex)
    return Database.GetCategory(categoryIndex)
end

local function IsCategoryVisible(categoryIndex)
    local category = GetCurrentCategory(categoryIndex)
    return category and Trim(category.name) ~= ""
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

function MainWindow.ApplyCategoryHighlight(button, isSelected)
    button.Selection:Hide()
    button.SelectionUnderline:Hide()

    for _, edge in pairs(button.SelectionOutline) do
        edge:Hide()
    end

    button.Text:SetShadowColor(
        button.defaultShadowR,
        button.defaultShadowG,
        button.defaultShadowB,
        button.defaultShadowA
    )
    button.Text:SetShadowOffset(button.defaultShadowX, button.defaultShadowY)

    if not isSelected then
        return
    end

    local color = settings.categoryHighlightColor
    local effect = settings.categoryHighlightEffect

    if effect == "background" then
        button.Selection:SetColorTexture(color.r, color.g, color.b, 0.85)
        button.Selection:Show()
    elseif effect == "outline" then
        local thickness = settings.categoryHighlightThickness

        button.SelectionOutline.top:SetHeight(thickness)
        button.SelectionOutline.bottom:SetHeight(thickness)
        button.SelectionOutline.left:SetWidth(thickness)
        button.SelectionOutline.right:SetWidth(thickness)

        for _, edge in pairs(button.SelectionOutline) do
            edge:SetColorTexture(color.r, color.g, color.b, 1)
            edge:Show()
        end
    elseif effect == "underline" then
        button.SelectionUnderline:SetHeight(settings.categoryHighlightThickness)
        button.SelectionUnderline:SetColorTexture(color.r, color.g, color.b, 1)
        button.SelectionUnderline:Show()
    elseif effect == "shadow" then
        button.Text:SetShadowColor(color.r, color.g, color.b, 1)
        button.Text:SetShadowOffset(2, -2)
    end
end

local function UpdateCategorySidebar()
    if not CategoryScrollChild then
        return
    end

    local visibleCount = 0

    for categoryIndex = 1, MAX_CATEGORIES do
        local button = categoryButtons[categoryIndex]
        local category = GetCurrentCategory(categoryIndex)

        if button and IsCategoryVisible(categoryIndex) then
            button:ClearAllPoints()
            button:SetPoint(
                "TOPLEFT",
                CategoryScrollChild,
                "TOPLEFT",
                0,
                -visibleCount * categoryButtonHeight
            )
            button.Text:SetText(category.name)

            local isSelected = categoryIndex == selectedCategoryIndex
            MainWindow.ApplyCategoryHighlight(button, isSelected)

            local textColor = isSelected
                and settings.selectedCategoryTextColor
                or settings.categoryTextColor

            button.Text:SetTextColor(
                textColor.r,
                textColor.g,
                textColor.b,
                1
            )

            button:Show()
            visibleCount = visibleCount + 1
        elseif button then
            button:Hide()
        end
    end

    CategoryScrollChild:SetHeight(math.max(visibleCount * categoryButtonHeight, 1))

    if visibleCount == 0 then
        CategoryEmptyLabel:Show()
    else
        CategoryEmptyLabel:Hide()
    end

    local maximumScroll = math.max(
        CategoryScrollChild:GetHeight() - CategoryScrollFrame:GetHeight(),
        0
    )
    CategoryScrollFrame:SetVerticalScroll(
        math.min(CategoryScrollFrame:GetVerticalScroll() or 0, maximumScroll)
    )
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
    MainWindow.NotifyActivity()

    for _, button in ipairs(buttonsPool) do
        button:Hide()
        button:ClearAllPoints()
        button:SetScript("OnClick", nil)
    end

    if not IsCategoryVisible(selectedCategoryIndex) then
        selectedCategoryIndex = FindFirstVisibleCategory()
    end

    settings.selectedCategory = selectedCategoryIndex or defaults.selectedCategory
    UpdateCategorySidebar()

    if not selectedCategoryIndex then
        ScrollChild:SetHeight(1)
        ScrollFrame:SetVerticalScroll(0)
        UpdateScrollIndicators()
        ScheduleInactiveFade()
        return
    end

    local category = GetCurrentCategory(selectedCategoryIndex)

    local visibleEmotes = GetVisibleEmotes(category)
    local dynamicY = 0

    for _, emote in ipairs(visibleEmotes) do
        local label = emote.label
        local defaultCommand = emote.defaultCommand
        local targetedCommand = emote.targetedCommand
        local emoteButton = GetContainerButton()

        emoteButton:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, -dynamicY)
        emoteButton.Text:SetText(label)
        emoteButton.Text:SetTextColor(
            settings.emoteTextColor.r,
            settings.emoteTextColor.g,
            settings.emoteTextColor.b,
            1
        )
        emoteButton:SetScript("OnClick", function()
            addon.Commands.ExecuteEmoteCommand(defaultCommand, targetedCommand)
        end)
        emoteButton:Show()

        dynamicY = dynamicY + emoteButtonHeight + 2
    end

    ScrollChild:SetHeight(math.max(dynamicY, 1))
    ScrollFrame:SetVerticalScroll(0)

    C_Timer.After(0, function()
        UpdateScrollIndicators()
    end)

    ScheduleInactiveFade()
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
        CategorySidebar:Hide()
        ScrollFrame:Hide()
        ScrollTopIndicator:Hide()
        ScrollBottomIndicator:Hide()
        MainFrame:SetHeight(collapsedHeight)
        CollapseBtn:SetText("+")
    else
        MainFrame:SetSize(settings.width, settings.height)
        CategorySidebar:Show()
        ScrollFrame:Show()
        CollapseBtn:SetText("-")
        MainWindow.UpdateMenu()
        C_Timer.After(0, UpdateScrollIndicators)
    end

    MainWindow.ApplyMovementLock()

    if settings.rememberMinimized then
        settings.minimized = isWindowCollapsed
    end
end

-- MAIN WINDOW
function MainWindow.CreateMainWindow()
    settings = Database.GetSettings()
    selectedCategoryIndex = settings.selectedCategory
    sidebarWidth = settings.sidebarWidth
    MainFrame = CreateFrame("Frame", "RPEmoteMenu", UIParent, "BackdropTemplate")
    MainFrame:SetSize(defaults.width, defaults.height)
    MainFrame:SetResizeBounds(minimumWidth, minimumHeight, maximumWidth, maximumHeight)
    MainFrame:SetClampedToScreen(true)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag("LeftButton")

    MainFrame:SetScript("OnDragStart", function(self)
        if not settings.locked then
            self:StartMoving()
        end
    end)

    MainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPosition()
    end)

    MainFrame:SetScript("OnSizeChanged", function(self, width)
        if CategorySidebar and ScrollFrame and ScrollChild
            and sidebarWidth > GetMaximumSidebarWidth(width) then
            MainWindow.ApplySidebarWidth(sidebarWidth)
            return
        end

        local contentWidth = math.max(width - sidebarWidth - 35, 1)

        if ScrollChild then
            ScrollChild:SetWidth(contentWidth)
        end

        for _, button in ipairs(buttonsPool) do
            button:SetWidth(math.max(contentWidth - 5, 1))
        end

        if ScrollFrame then
            C_Timer.After(0, UpdateScrollIndicators)
        end
    end)

    local title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 10, -10)
    title:SetText("RP Emote Menu " .. addon.VERSION)
    title:SetTextColor(1, 1, 1, 1)

    CategorySidebar = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
    CategorySidebar:SetWidth(sidebarWidth)
    CategorySidebar:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 5, -36)
    CategorySidebar:SetPoint("BOTTOMLEFT", MainFrame, "BOTTOMLEFT", 5, 10)
    CategorySidebar:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground"
    })
    SidebarDivider = CategorySidebar:CreateTexture(nil, "OVERLAY")
    SidebarDivider:SetWidth(1)
    SidebarDivider:SetPoint("TOPRIGHT", CategorySidebar, "TOPRIGHT", 0, 0)
    SidebarDivider:SetPoint("BOTTOMRIGHT", CategorySidebar, "BOTTOMRIGHT", 0, 0)

    CategoryScrollFrame = CreateFrame("ScrollFrame", nil, CategorySidebar)
    CategoryScrollFrame:SetPoint("TOPLEFT", CategorySidebar, "TOPLEFT", 3, -3)
    CategoryScrollFrame:SetPoint("BOTTOMRIGHT", CategorySidebar, "BOTTOMRIGHT", -4, 3)
    CategoryScrollFrame:EnableMouseWheel(true)

    CategoryScrollChild = CreateFrame("Frame", nil, CategoryScrollFrame)
    CategoryScrollChild:SetSize(sidebarWidth - 7, 1)
    CategoryScrollFrame:SetScrollChild(CategoryScrollChild)
    CategoryScrollFrame:SetScript("OnMouseWheel", function(self, direction)
        local maximumScroll = math.max(
            CategoryScrollChild:GetHeight() - self:GetHeight(),
            0
        )
        local scroll = (self:GetVerticalScroll() or 0)
            - (direction * categoryButtonHeight)

        self:SetVerticalScroll(math.max(0, math.min(maximumScroll, scroll)))
    end)

    CategoryEmptyLabel = CategorySidebar:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontDisableSmall"
    )
    CategoryEmptyLabel:SetPoint("TOPLEFT", CategorySidebar, "TOPLEFT", 7, -9)
    CategoryEmptyLabel:SetPoint("TOPRIGHT", CategorySidebar, "TOPRIGHT", -7, -9)
    CategoryEmptyLabel:SetJustifyH("LEFT")
    CategoryEmptyLabel:SetText("No categories")
    CategoryEmptyLabel:Hide()

    for categoryIndex = 1, MAX_CATEGORIES do
        local button = CreateFrame("Button", nil, CategoryScrollChild)
        button:SetSize(sidebarWidth - 7, categoryButtonHeight)
        button.categoryIndex = categoryIndex

        button.Selection = button:CreateTexture(nil, "BACKGROUND")
        button.Selection:SetAllPoints(button)
        button.Selection:Hide()

        button.SelectionOutline = {
            top = button:CreateTexture(nil, "ARTWORK"),
            bottom = button:CreateTexture(nil, "ARTWORK"),
            left = button:CreateTexture(nil, "ARTWORK"),
            right = button:CreateTexture(nil, "ARTWORK")
        }

        button.SelectionOutline.top:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.SelectionOutline.top:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        button.SelectionOutline.bottom:SetPoint(
            "BOTTOMLEFT",
            button,
            "BOTTOMLEFT",
            0,
            0
        )
        button.SelectionOutline.bottom:SetPoint(
            "BOTTOMRIGHT",
            button,
            "BOTTOMRIGHT",
            0,
            0
        )
        button.SelectionOutline.left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.SelectionOutline.left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        button.SelectionOutline.right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        button.SelectionOutline.right:SetPoint(
            "BOTTOMRIGHT",
            button,
            "BOTTOMRIGHT",
            0,
            0
        )

        for _, edge in pairs(button.SelectionOutline) do
            edge:Hide()
        end

        button.SelectionUnderline = button:CreateTexture(nil, "ARTWORK")
        button.SelectionUnderline:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        button.SelectionUnderline:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button.SelectionUnderline:Hide()

        button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        button.Text:SetPoint("LEFT", button, "LEFT", 6, 0)
        button.Text:SetPoint("RIGHT", button, "RIGHT", -5, 0)
        button.Text:SetJustifyH("LEFT")
        button.Text:SetWordWrap(false)
        button.defaultShadowX, button.defaultShadowY = button.Text:GetShadowOffset()
        button.defaultShadowR,
            button.defaultShadowG,
            button.defaultShadowB,
            button.defaultShadowA = button.Text:GetShadowColor()
        ApplyFont(
            button.Text,
            settings.categoryFont,
            settings.categoryFontSize,
            settings.categoryTextColor
        )

        button:SetHighlightTexture(
            "Interface\\QuestFrame\\UI-QuestTitleHighlight",
            "ADD"
        )
        button:SetScript("OnClick", function(self)
            MainWindow.SetSelectedCategory(self.categoryIndex)
            MainWindow.UpdateMenu()
        end)
        button:SetScript("OnEnter", function(self)
            if self.Text:IsTruncated() then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.Text:GetText())
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        button:Hide()

        categoryButtons[categoryIndex] = button
    end

    ScrollFrame = CreateFrame("ScrollFrame", nil, MainFrame, "UIPanelScrollFrameTemplate")
    ScrollFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", sidebarWidth + 10, -40)
    ScrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -25, 10)

    ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollChild:SetSize(math.max(defaults.width - sidebarWidth - 35, 1), 1)
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
        addon.Settings.OpenAbout()
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
        if button == "LeftButton" and not settings.locked and not isWindowCollapsed then
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
    MainWindow.ApplySidebarWidth(settings.sidebarWidth)
    MainWindow.ApplyMovementLock()
    MainWindow.ApplySettingsGearVisibility()
    MainWindow.ApplyAppearance()

    MainFrame:HookScript("OnEnter", MainWindow.NotifyActivity)
    MainFrame:HookScript("OnLeave", ScheduleInactiveFade)

    if settings.rememberMinimized then
        isWindowCollapsed = settings.minimized
    else
        isWindowCollapsed = false
    end

    UpdateWindowCollapse()

    if settings.showAtLogin then
        MainFrame:Show()
    else
        MainFrame:Hide()
    end
end

function MainWindow.SetSelectedCategory(categoryIndex)
    if type(categoryIndex) ~= "number"
        or categoryIndex % 1 ~= 0
        or categoryIndex < 1
        or categoryIndex > MAX_CATEGORIES then
        return
    end

    selectedCategoryIndex = categoryIndex

    if settings then
        settings.selectedCategory = categoryIndex
    end
end

function MainWindow.IsCollapsed()
    return isWindowCollapsed
end

function MainWindow.GetFrame()
    return MainFrame
end
