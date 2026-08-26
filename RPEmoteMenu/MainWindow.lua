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
local columnChromeWidth = addon.COLUMN_CHROME_WIDTH
local minimumWidth = addon.MIN_SIDEBAR_WIDTH
    + addon.MIN_EMOTE_COLUMN_WIDTH + columnChromeWidth
local minimumHeight = 150
local maximumWidth = 600
local maximumHeight = 600
local sidebarWidth = defaults.sidebarWidth
local emoteColumnWidth = defaults.emoteColumnWidth
local minimumSidebarWidth = addon.MIN_SIDEBAR_WIDTH
local maximumSidebarWidth = addon.MAX_SIDEBAR_WIDTH
local minimumEmoteColumnWidth = addon.MIN_EMOTE_COLUMN_WIDTH
local maximumEmoteColumnWidth = addon.MAX_EMOTE_COLUMN_WIDTH
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
local isApplyingColumnSize = false
local fontRefreshGeneration = 0

local function RefreshGeneralWindowFields()
    if addon.Settings and addon.Settings.RefreshGeneralWindowFields then
        addon.Settings.RefreshGeneralWindowFields()
    end
end

local function ClampColumnWidth(value, minimum, maximum, fallback)
    value = math.floor(tonumber(value) or fallback)
    return math.max(minimum, math.min(maximum, value))
end

local function DistributeWindowWidth(width)
    local target = math.max(minimumWidth, math.min(maximumWidth,
        math.floor(tonumber(width) or settings.width or defaults.width)))
    local left = ClampColumnWidth(
        sidebarWidth, minimumSidebarWidth, maximumSidebarWidth, defaults.sidebarWidth
    )
    local right = ClampColumnWidth(
        emoteColumnWidth,
        minimumEmoteColumnWidth,
        maximumEmoteColumnWidth,
        defaults.emoteColumnWidth
    )
    local delta = target - columnChromeWidth - left - right

    if delta > 0 then
        local rightChange = math.min(delta, maximumEmoteColumnWidth - right)
        right = right + rightChange
        left = left + math.min(delta - rightChange, maximumSidebarWidth - left)
    elseif delta < 0 then
        local remaining = -delta
        local rightChange = math.min(remaining, right - minimumEmoteColumnWidth)
        right = right - rightChange
        left = left - math.min(remaining - rightChange, left - minimumSidebarWidth)
    end

    return left, right, left + right + columnChromeWidth
end

local ApplyColumnLayout

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
    sidebarWidth, emoteColumnWidth, width = DistributeWindowWidth(width)

    settings.point = "TOPLEFT"
    settings.relativePoint = "BOTTOMLEFT"
    settings.x = x
    settings.y = y
    settings.width = width
    settings.height = height

    MainFrame:ClearAllPoints()
    MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)

    isApplyingColumnSize = true
    if isWindowCollapsed then
        MainFrame:SetSize(width, collapsedHeight)
    else
        MainFrame:SetSize(width, height)
    end
    isApplyingColumnSize = false
    ApplyColumnLayout()

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
    sidebarWidth = settings.sidebarWidth
    emoteColumnWidth = settings.emoteColumnWidth
    sidebarWidth, emoteColumnWidth, width = DistributeWindowWidth(width)
    settings.sidebarWidth = sidebarWidth
    settings.emoteColumnWidth = emoteColumnWidth
    settings.width = width
    settings.height = height
    isApplyingColumnSize = true
    MainFrame:SetSize(width, height)
    isApplyingColumnSize = false

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
    settings.emoteColumnWidth = defaults.emoteColumnWidth
    sidebarWidth = defaults.sidebarWidth
    emoteColumnWidth = defaults.emoteColumnWidth

    -- Resolve the default CENTER anchor using the restored full-size window.
    -- Otherwise its previous dimensions shift the position until a second reset.
    isApplyingColumnSize = true
    MainFrame:SetSize(defaults.width, defaults.height)
    isApplyingColumnSize = false
    RestoreWindowPosition()

    if isWindowCollapsed then
        MainFrame:SetHeight(collapsedHeight)
    end

    MainWindow.ApplySidebarWidth(defaults.sidebarWidth)
    RefreshGeneralWindowFields()
end

ApplyColumnLayout = function()
    if not MainFrame or not CategorySidebar or not CategoryScrollChild
        or not ScrollFrame or not ScrollChild then
        return
    end

    settings.sidebarWidth = sidebarWidth
    settings.emoteColumnWidth = emoteColumnWidth
    settings.width = sidebarWidth + emoteColumnWidth + columnChromeWidth

    CategorySidebar:SetWidth(sidebarWidth)
    CategoryScrollChild:SetWidth(sidebarWidth - 7)

    for _, button in ipairs(categoryButtons) do
        button:SetWidth(sidebarWidth - 7)
    end

    ScrollFrame:ClearAllPoints()
    ScrollFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", sidebarWidth + 10, -40)
    ScrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -25, 10)

    ScrollChild:SetWidth(emoteColumnWidth)

    for _, button in ipairs(buttonsPool) do
        button:SetWidth(math.max(emoteColumnWidth - 5, 1))
    end

    RefreshGeneralWindowFields()
end

local function ApplyExplicitColumnWidths(left, right)
    sidebarWidth = ClampColumnWidth(
        left, minimumSidebarWidth, maximumSidebarWidth, defaults.sidebarWidth
    )
    emoteColumnWidth = ClampColumnWidth(
        right,
        minimumEmoteColumnWidth,
        maximumEmoteColumnWidth,
        defaults.emoteColumnWidth
    )
    local totalWidth = sidebarWidth + emoteColumnWidth + columnChromeWidth
    isApplyingColumnSize = true
    MainFrame:SetWidth(totalWidth)
    isApplyingColumnSize = false
    ApplyColumnLayout()
end

function MainWindow.ApplySidebarWidth(width)
    ApplyExplicitColumnWidths(width, emoteColumnWidth)
end

function MainWindow.ApplyEmoteColumnWidth(width)
    ApplyExplicitColumnWidths(sidebarWidth, width)
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
    local currentText = forceRefresh and fontString:GetText()

    if forceRefresh and currentSize == size then
        local refreshSize = size < 24 and size + 1 or size - 1
        fontString:SetFont(fontFile, refreshSize, fontFlags or "")
    end

    local applied = fontString:SetFont(fontFile, size, fontFlags or "")

    if not applied then
        fontString:SetFont(STANDARD_TEXT_FONT, size, fontFlags or "")
    end

    if forceRefresh and currentText then
        fontString:SetText("")
        fontString:SetText(currentText)
    end

    if applied
        and currentText
        and currentText ~= ""
        and fontString:GetStringWidth() <= 0 then
        applied = false
        fontString:SetFont(STANDARD_TEXT_FONT, size, fontFlags or "")
        fontString:SetText("")
        fontString:SetText(currentText)
    end

    fontString:SetTextColor(color.r, color.g, color.b, 1)
    return applied
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

function MainWindow.RefreshFontDisplays(updateLayout)
    if not MainFrame then
        return false
    end

    local categoryApplied = true
    local emoteApplied = true
    categoryButtonHeight = math.max(24, settings.categoryFontSize + 10)
    emoteButtonHeight = math.max(20, settings.emoteFontSize + 8)

    -- Build and position every required button before applying fonts. Otherwise
    -- a newly created final label can miss the pane-wide consistency pass.
    if updateLayout ~= false then
        MainWindow.UpdateMenu()
    end

    for _, button in ipairs(categoryButtons) do
        button:SetHeight(categoryButtonHeight)
        local textColor = button.categoryIndex == selectedCategoryIndex
            and settings.selectedCategoryTextColor
            or settings.categoryTextColor

        if not ApplyFont(
            button.Text,
            settings.categoryFont,
            settings.categoryFontSize,
            textColor,
            true
        ) then
            categoryApplied = false
        end

        for _, outlineText in ipairs(button.TextOutline) do
            if not ApplyFont(
                outlineText,
                settings.categoryFont,
                settings.categoryFontSize,
                settings.categoryHighlightColor,
                true
            ) then
                categoryApplied = false
            end
        end
    end

    if not categoryApplied then
        for _, button in ipairs(categoryButtons) do
            local textColor = button.categoryIndex == selectedCategoryIndex
                and settings.selectedCategoryTextColor
                or settings.categoryTextColor
            ApplyFont(
                button.Text,
                defaults.categoryFont,
                settings.categoryFontSize,
                textColor,
                true
            )
            for _, outlineText in ipairs(button.TextOutline) do
                ApplyFont(
                    outlineText,
                    defaults.categoryFont,
                    settings.categoryFontSize,
                    settings.categoryHighlightColor,
                    true
                )
            end
        end
    end

    for _, button in ipairs(buttonsPool) do
        button:SetHeight(emoteButtonHeight)
        if not ApplyFont(
            button.Text,
            settings.emoteFont,
            settings.emoteFontSize,
            settings.emoteTextColor,
            true
        ) then
            emoteApplied = false
        end
    end

    if not emoteApplied then
        for _, button in ipairs(buttonsPool) do
            ApplyFont(
                button.Text,
                defaults.emoteFont,
                settings.emoteFontSize,
                settings.emoteTextColor,
                true
            )
        end
    end

    local emoteColor = settings.emoteTextColor
    if ScrollTopIndicator then
        ScrollTopIndicator:SetColorTexture(
            emoteColor.r, emoteColor.g, emoteColor.b, 1
        )
    end
    if ScrollBottomIndicator then
        ScrollBottomIndicator:SetColorTexture(
            emoteColor.r, emoteColor.g, emoteColor.b, 1
        )
    end

    if addon.Settings and addon.Settings.RefreshFontControls then
        addon.Settings.RefreshFontControls()
    end

    return categoryApplied and emoteApplied
end

function MainWindow.RefreshFont()
    return MainWindow.RefreshFontDisplays()
end

function MainWindow.ScheduleFontRefreshes(skipImmediateRefresh)
    fontRefreshGeneration = fontRefreshGeneration + 1
    local requestedGeneration = fontRefreshGeneration

    if not skipImmediateRefresh then
        MainWindow.RefreshFontDisplays()
    end

    for _, delay in ipairs({
        0, 0.25, 0.75, 1.5, 3, 5, 8, 12, 18, 24, 30
    }) do
        C_Timer.After(delay, function()
            if requestedGeneration == fontRefreshGeneration then
                MainWindow.RefreshFontDisplays(false)
            end
        end)
    end
end

function MainWindow.ApplyAppearance()
    if not MainFrame then
        return
    end

    local categoryBackground = settings.categoryBackgroundColor
    local emoteBackground = settings.emoteBackgroundColor
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
        emoteBackground.r,
        emoteBackground.g,
        emoteBackground.b,
        settings.backgroundOpacity
    )
    MainFrame:SetBackdropBorderColor(border.r, border.g, border.b, 1)

    CategorySidebar:SetBackdropColor(
        categoryBackground.r,
        categoryBackground.g,
        categoryBackground.b,
        settings.backgroundOpacity
    )

    if settings.borderStyle == "none" then
        SidebarDivider:Hide()
    else
        SidebarDivider:SetColorTexture(border.r, border.g, border.b, 0.9)
        SidebarDivider:Show()
    end

    MainWindow.RefreshFontDisplays()
    MainWindow.ApplyFadeSettings()
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
    for _, outlineText in ipairs(button.TextOutline) do
        outlineText:Hide()
    end

    button.Text:SetShadowColor(
        button.defaultShadowR,
        button.defaultShadowG,
        button.defaultShadowB,
        button.defaultShadowA
    )
    button.Text:SetShadowOffset(button.defaultShadowX, button.defaultShadowY)

    local strength = isSelected and 1 or (button.isHovered and 0.5 or 0)

    if strength == 0 then
        return
    end

    local color = settings.categoryHighlightColor
    local effect = settings.categoryHighlightEffect

    if effect == "background" then
        button.Selection:SetColorTexture(
            color.r,
            color.g,
            color.b,
            0.85 * strength
        )
        button.Selection:Show()
    elseif effect == "outline" then
        local thickness = settings.categoryHighlightThickness
        for _, outlineText in ipairs(button.TextOutline) do
            outlineText:ClearAllPoints()
            outlineText:SetPoint(
                "LEFT",
                button.Text,
                "LEFT",
                outlineText.offsetX * thickness,
                outlineText.offsetY * thickness
            )
            outlineText:SetPoint(
                "RIGHT",
                button.Text,
                "RIGHT",
                outlineText.offsetX * thickness,
                outlineText.offsetY * thickness
            )
            outlineText:SetTextColor(color.r, color.g, color.b, strength)
            outlineText:Show()
        end
    elseif effect == "underline" then
        button.SelectionUnderline:SetHeight(settings.categoryHighlightThickness)
        button.SelectionUnderline:SetColorTexture(
            color.r, color.g, color.b, strength
        )
        button.SelectionUnderline:Show()
    elseif effect == "shadow" then
        button.Text:SetShadowColor(color.r, color.g, color.b, strength)
        button.Text:SetShadowOffset(2, -2)
    elseif effect == "separator" then
        button.SelectionOutline.right:SetWidth(settings.categoryHighlightThickness)
        button.SelectionOutline.right:SetColorTexture(
            color.r, color.g, color.b, strength
        )
        button.SelectionOutline.right:Show()
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
            for _, outlineText in ipairs(button.TextOutline) do
                outlineText:SetText(category.name)
            end

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
    emoteColumnWidth = settings.emoteColumnWidth
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
        if isApplyingColumnSize then return end
        sidebarWidth, emoteColumnWidth, width = DistributeWindowWidth(width)
        settings.sidebarWidth = sidebarWidth
        settings.emoteColumnWidth = emoteColumnWidth
        settings.width = width
        if math.abs(self:GetWidth() - width) > 0.5 then
            isApplyingColumnSize = true
            self:SetWidth(width)
            isApplyingColumnSize = false
        end
        if ApplyColumnLayout then ApplyColumnLayout() end
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
        button.TextOutline = {}
        for _, offset in ipairs({
            {-1, -1}, {-1, 0}, {-1, 1}, {0, -1},
            {0, 1}, {1, -1}, {1, 0}, {1, 1}
        }) do
            local outlineText = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            outlineText:SetPoint("LEFT", button.Text, "LEFT", offset[1], offset[2])
            outlineText:SetPoint("RIGHT", button.Text, "RIGHT", offset[1], offset[2])
            outlineText:SetJustifyH("LEFT")
            outlineText:SetWordWrap(false)
            outlineText:SetTextColor(1, 1, 1, 1)
            outlineText.offsetX = offset[1]
            outlineText.offsetY = offset[2]
            outlineText:Hide()
            button.TextOutline[#button.TextOutline + 1] = outlineText
        end
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

        button:SetScript("OnClick", function(self)
            MainWindow.SetSelectedCategory(self.categoryIndex)
            MainWindow.UpdateMenu()
        end)
        button:SetScript("OnEnter", function(self)
            self.isHovered = true
            MainWindow.ApplyCategoryHighlight(
                self,
                self.categoryIndex == selectedCategoryIndex
            )
            if self.Text:IsTruncated() then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.Text:GetText())
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function(self)
            self.isHovered = false
            MainWindow.ApplyCategoryHighlight(
                self,
                self.categoryIndex == selectedCategoryIndex
            )
            GameTooltip:Hide()
        end)
        button:Hide()

        categoryButtons[categoryIndex] = button
    end

    ScrollFrame = CreateFrame("ScrollFrame", nil, MainFrame, "UIPanelScrollFrameTemplate")
    ScrollFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", sidebarWidth + 10, -40)
    ScrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -25, 10)

    ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollChild:SetSize(emoteColumnWidth, 1)
    ScrollFrame:SetScrollChild(ScrollChild)

    ScrollTopIndicator = MainFrame:CreateTexture(nil, "OVERLAY")
    ScrollTopIndicator:SetHeight(1)
    ScrollTopIndicator:SetPoint("TOPLEFT", ScrollFrame, "TOPLEFT", 6, -1)
    ScrollTopIndicator:SetPoint("TOPRIGHT", ScrollFrame, "TOPRIGHT", -6, -1)
    ScrollTopIndicator:SetColorTexture(
        settings.emoteTextColor.r,
        settings.emoteTextColor.g,
        settings.emoteTextColor.b,
        1
    )
    ScrollTopIndicator:Hide()

    ScrollBottomIndicator = MainFrame:CreateTexture(nil, "OVERLAY")
    ScrollBottomIndicator:SetHeight(1)
    ScrollBottomIndicator:SetPoint("BOTTOMLEFT", ScrollFrame, "BOTTOMLEFT", 6, 1)
    ScrollBottomIndicator:SetPoint("BOTTOMRIGHT", ScrollFrame, "BOTTOMRIGHT", -6, 1)
    ScrollBottomIndicator:SetColorTexture(
        settings.emoteTextColor.r,
        settings.emoteTextColor.g,
        settings.emoteTextColor.b,
        1
    )
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

    MainFrame:HookScript("OnEnter", MainWindow.NotifyActivity)
    MainFrame:HookScript("OnLeave", ScheduleInactiveFade)

    MainWindow.ApplyProfileSettings()

    if settings.showAtLogin then
        MainFrame:Show()
    else
        MainFrame:Hide()
    end
end

function MainWindow.ApplyProfileSettings()
    settings = Database.GetSettings()
    selectedCategoryIndex = settings.selectedCategory
    sidebarWidth = settings.sidebarWidth
    emoteColumnWidth = settings.emoteColumnWidth

    if not MainFrame then
        return
    end

    -- Restore size first so legacy non-TOPLEFT anchors can be converted accurately.
    RestoreWindowSize()
    RestoreWindowPosition()
    MainWindow.ApplySidebarWidth(settings.sidebarWidth)
    MainWindow.ApplyMovementLock()
    MainWindow.ApplySettingsGearVisibility()
    MainWindow.ApplyAppearance()

    isWindowCollapsed = settings.rememberMinimized and settings.minimized or false
    UpdateWindowCollapse()
    MainWindow.UpdateMenu()
    MainWindow.ScheduleFontRefreshes(true)
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
