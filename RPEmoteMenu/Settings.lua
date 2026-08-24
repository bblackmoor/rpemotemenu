local _, addon = ...

addon.Settings = {}

local AddonSettings = addon.Settings
local MainWindow = addon.MainWindow
local Database = addon.Database
local settings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local settingsCategory
local generalSettingsCategory
local categorySettingsCategories = {}

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
        local category = Database.GetCategory(self.categoryIndex)

        if self.emoteIndex then
            return category.emotes[self.emoteIndex][self.fieldName] or ""
        end

        return category[self.fieldName] or ""
    end

    local function SetCurrentValue(self, value)
        local category = Database.GetCategory(self.categoryIndex)

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
        MainWindow.UpdateMenu()
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
        "Version 1.6\n" ..
        "Author    Brandon Blackmoor\n" ..
        "Category  Roleplay\n" ..
        "License   GPL-3.0\n\n" ..

        "Slash Commands\n" ..
        "    /rpem - Show or hide the RP Emote Menu.\n" ..
        "    /rpem config - Open the addon settings.\n" ..
        "    /rpem options - Open the addon settings.\n" ..
        "    /rpem settings - Open the addon settings.\n\n" ..

        "Tokens supported by /e commands\n" ..
        "    {target}       Target's name without the realm.\n" ..
        "    {target-full}  Target's name including the realm when applicable.\n" ..
        "    {player}       Your character's name without the realm.\n" ..
        "    {player-full}  Your character's name including the realm when applicable."
    )
    return panel
end

local function CreateIntegerEditBox(parent, x, y, width, getValue, applyValue)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(width, 24)
    editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:EnableMouseWheel(true)
    editBox:SetMaxLetters(6)
    editBox:SetFont(STANDARD_TEXT_FONT, 12, "")
    editBox:SetTextColor(1, 1, 1, 1)

    editBox.RefreshValue = function(self)
        local value = math.floor(tonumber(getValue()) or 0)
        self:SetText(tostring(value))
        self:SetCursorPosition(0)
    end

    local function Commit(self)
        local value = tonumber(self:GetText())

        if not value then
            self:RefreshValue()
            return
        end

        applyValue(math.floor(value))
        self:RefreshValue()
    end

    editBox:SetScript("OnEnterPressed", function(self)
        Commit(self)
        self:ClearFocus()
    end)

    editBox:SetScript("OnEditFocusLost", Commit)
    editBox:SetScript("OnEscapePressed", function(self)
        self:RefreshValue()
        self:ClearFocus()
    end)

    editBox:SetScript("OnMouseWheel", function(self, delta)
        local currentValue = math.floor(tonumber(getValue()) or 0)

        if delta > 0 then
            currentValue = currentValue + 1
        elseif delta < 0 then
            currentValue = currentValue - 1
        else
            return
        end

        applyValue(currentValue)
        self:RefreshValue()
    end)

    editBox:RefreshValue()
    return editBox
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
        function() return settings.locked end,
        function(value)
            settings.locked = value
            MainWindow.ApplyMovementLock()
        end)

    CreateCheckbox(panel, "Hide settings gear icon", -105,
        function() return settings.hideSettingsGear end,
        function(value)
            settings.hideSettingsGear = value
            MainWindow.ApplySettingsGearVisibility()
        end)

    CreateCheckbox(panel, "Show the addon at login", -140,
        function() return settings.showAtLogin end,
        function(value) settings.showAtLogin = value end)

    CreateCheckbox(panel, "Remember whether the main window was minimized", -175,
        function() return settings.rememberMinimized end,
        function(value)
            settings.rememberMinimized = value
            settings.minimized = value and MainWindow.IsCollapsed() or false
        end)

    local positionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    positionLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -220)
    positionLabel:SetText("Current window position")

    local xLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xLabel:SetPoint("BOTTOM", panel, "TOPLEFT", 225, -215)
    xLabel:SetText("X")

    local yLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    yLabel:SetPoint("BOTTOM", panel, "TOPLEFT", 305, -215)
    yLabel:SetText("Y")

    local positionXBox = CreateIntegerEditBox(
        panel, 190, -216, 70,
        function() return settings.x end,
        function(value)
            MainWindow.ApplyWindowGeometry(
                value,
                settings.y,
                settings.width,
                settings.height
            )
        end
    )

    local positionYBox = CreateIntegerEditBox(
        panel, 270, -216, 70,
        function() return settings.y end,
        function(value)
            MainWindow.ApplyWindowGeometry(
                settings.x,
                value,
                settings.width,
                settings.height
            )
        end
    )

    local sizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -255)
    sizeLabel:SetText("Current window size")

    local widthLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    widthLabel:SetPoint("BOTTOM", panel, "TOPLEFT", 225, -250)
    widthLabel:SetText("Width")

    local heightLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    heightLabel:SetPoint("BOTTOM", panel, "TOPLEFT", 305, -250)
    heightLabel:SetText("Height")

    local widthBox = CreateIntegerEditBox(
        panel, 190, -251, 70,
        function() return settings.width end,
        function(value)
            MainWindow.ApplyWindowGeometry(
                settings.x,
                settings.y,
                value,
                settings.height
            )
        end
    )

    local heightBox = CreateIntegerEditBox(
        panel, 270, -251, 70,
        function() return settings.height end,
        function(value)
            MainWindow.ApplyWindowGeometry(
                settings.x,
                settings.y,
                settings.width,
                value
            )
        end
    )

    AddonSettings.RefreshGeneralWindowFields = function()
        positionXBox:RefreshValue()
        positionYBox:RefreshValue()
        widthBox:RefreshValue()
        heightBox:RefreshValue()
    end

    panel:SetScript("OnShow", AddonSettings.RefreshGeneralWindowFields)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(230, 24)
    resetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -300)
    resetButton:SetText("Reset Window Position and Size")
    resetButton:SetScript("OnClick", MainWindow.ResetWindowPosition)

    local resetAllButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAllButton:SetSize(260, 24)
    resetAllButton:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -10)
    resetAllButton:SetText("Reset All Default Categories and Emotes")
    resetAllButton:SetScript("OnClick", Database.ResetAllCategoriesToDefaults)

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
        Database.ResetCategoryToDefaults(categoryIndex)
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

function AddonSettings.CreateSettingsPanel()
    settings = Database.GetSettings()
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

    AddonSettings.RefreshEditors = function(categoryIndex)
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

AddonSettings.Open = function()
    if generalSettingsCategory then
        Settings.OpenToCategory(generalSettingsCategory:GetID())
    elseif settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end
