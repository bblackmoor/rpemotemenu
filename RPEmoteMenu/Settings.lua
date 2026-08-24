local _, addon = ...

addon.Settings = {}

local AddonSettings = addon.Settings
local MainWindow = addon.MainWindow
local Database = addon.Database
local Serialization = addon.Serialization
local settings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local settingsCategory
local generalSettingsCategory
local profilesSettingsCategory
local categorySettingsCategories = {}
local resetAllCategoriesButton
local exchangeDialog

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
        if not Database.CanEditActiveProfile() then
            return false
        end

        local category = Database.GetCategory(self.categoryIndex)

        if self.emoteIndex then
            category.emotes[self.emoteIndex][self.fieldName] = value
        else
            category[self.fieldName] = value
        end

        return true
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

        if Database.CanEditActiveProfile() then
            self:Enable()
            self:SetTextColor(1, 1, 1, 1)
        else
            self:ClearFocus()
            self:Disable()
            self:SetTextColor(0.65, 0.65, 0.65, 1)
        end
    end

    -- Blizzard's Settings panel can clear edit-box text during layout.
    -- Reapply the saved value after the box is shown. Later profile changes and
    -- reset actions refresh their editors explicitly, avoiding per-frame polling.
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

    local function Commit(self)
        if SetCurrentValue(self, self:GetText() or "") then
            MainWindow.UpdateMenu()
        else
            DisplayCurrentValue(self)
        end
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

local function GetExchangeDialog()
    if exchangeDialog then
        return exchangeDialog
    end

    local dialog = CreateFrame(
        "Frame",
        "RPEmoteMenuExchangeDialog",
        UIParent,
        "BackdropTemplate"
    )
    dialog:SetSize(620, 470)
    dialog:SetPoint("CENTER", UIParent, "CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetClampedToScreen(true)
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    dialog:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
    dialog:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    dialog:Hide()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "RPEmoteMenuExchangeDialog")
    end

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -16)
    dialog.title = title

    local closeIcon = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeIcon:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -4, -4)
    closeIcon:SetScript("OnClick", function()
        dialog:Hide()
    end)

    local instructions = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    instructions:SetWidth(570)
    instructions:SetJustifyH("LEFT")
    instructions:SetTextColor(0.8, 0.8, 0.8)
    dialog.instructions = instructions

    local textBackground = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    textBackground:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -80)
    textBackground:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -42, 80)
    textBackground:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    textBackground:SetBackdropColor(0.04, 0.04, 0.04, 1)
    textBackground:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, textBackground, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", textBackground, "TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", textBackground, "BOTTOMRIGHT", -5, 5)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFont(STANDARD_TEXT_FONT, 12, "")
    editBox:SetTextColor(1, 1, 1, 1)
    editBox:SetWidth(540)
    editBox:SetHeight(300)
    editBox:SetTextInsets(4, 4, 4, 4)
    scrollFrame:SetScrollChild(editBox)
    dialog.editBox = editBox

    local status = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 18, 49)
    status:SetWidth(570)
    status:SetJustifyH("LEFT")
    dialog.status = status

    local actionButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    actionButton:SetSize(120, 24)
    actionButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -144, 14)
    dialog.actionButton = actionButton

    local closeButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    closeButton:SetSize(110, 24)
    closeButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -18, 14)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    local function SetStatus(message, isError)
        status:SetText(message or "")

        if isError then
            status:SetTextColor(1, 0.35, 0.35, 1)
        else
            status:SetTextColor(0.35, 1, 0.45, 1)
        end
    end

    function dialog:UpdateActionState()
        if self.mode == "import" then
            local hasText = strtrim(editBox:GetText() or "") ~= ""
            actionButton:SetEnabled(Database.CanEditActiveProfile() and hasText)
        else
            actionButton:SetEnabled(true)
        end
    end

    editBox:SetScript("OnTextChanged", function(self, userInput)
        local text = self:GetText() or ""
        local charactersPerLine = math.max(1, math.floor((self:GetWidth() - 8) / 7))
        local lineCount = 0

        for line in (text .. "\n"):gmatch("([^\n]*)\n") do
            lineCount = lineCount + math.max(1, math.ceil(#line / charactersPerLine))
        end

        self:SetHeight(math.max(scrollFrame:GetHeight() or 0, (lineCount * 16) + 12))

        if userInput then
            SetStatus("")
        end

        dialog:UpdateActionState()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        dialog:Hide()
    end)

    actionButton:SetScript("OnClick", function()
        if dialog.mode == "export" then
            editBox:SetFocus()
            editBox:HighlightText()
            SetStatus("Press Ctrl+C to copy the selected text.")
            return
        end

        local success
        local result

        if dialog.dataType == "profile" then
            success, result = Serialization.ImportProfile(editBox:GetText())
        else
            success, result = Serialization.ImportCategory(
                dialog.categoryIndex,
                editBox:GetText()
            )
        end

        if success then
            editBox:SetText("")
            dialog:UpdateActionState()

            if dialog.dataType == "profile" then
                SetStatus(
                    "Imported profile " .. result .. " into "
                    .. Database.GetActiveProfileName() .. "."
                )
            else
                SetStatus("Imported category " .. result .. ".")
            end
        else
            SetStatus(result, true)
            dialog:UpdateActionState()
        end
    end)

    dialog:SetScript("OnHide", function()
        editBox:ClearFocus()
    end)

    function dialog:OpenExport(categoryIndex)
        local exported, errorMessage = Serialization.ExportCategory(categoryIndex)
        if not exported then
            return false, errorMessage
        end

        self.mode = "export"
        self.dataType = "category"
        self.categoryIndex = categoryIndex
        title:SetText("Export Category " .. categoryIndex)
        instructions:SetText("Copy this JSON to share or save the category and its emotes.")
        actionButton:SetText("Select All")
        SetStatus("")
        editBox:SetText(exported)
        editBox:SetCursorPosition(0)
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        editBox:HighlightText()
        return true
    end

    function dialog:OpenImport(categoryIndex)
        if not Database.CanEditActiveProfile() then
            return false, "The Default profile cannot receive imports."
        end

        self.mode = "import"
        self.dataType = "category"
        self.categoryIndex = categoryIndex
        title:SetText("Import Category " .. categoryIndex)
        instructions:SetText("Paste exported category JSON below. Importing replaces this category.")
        actionButton:SetText("Import")
        SetStatus("")
        editBox:SetText("")
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        return true
    end

    function dialog:OpenProfileExport()
        local exported, errorMessage = Serialization.ExportProfile()
        if not exported then
            return false, errorMessage
        end

        self.mode = "export"
        self.dataType = "profile"
        self.categoryIndex = nil
        title:SetText("Export Profile: " .. Database.GetActiveProfileName())
        instructions:SetText("Copy this JSON to share or save every category and emote in this profile.")
        actionButton:SetText("Select All")
        SetStatus("")
        editBox:SetText(exported)
        editBox:SetCursorPosition(0)
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        editBox:HighlightText()
        return true
    end

    function dialog:OpenProfileImport()
        if not Database.CanEditActiveProfile() then
            return false, "The Default profile cannot receive imports."
        end

        self.mode = "import"
        self.dataType = "profile"
        self.categoryIndex = nil
        title:SetText("Import Profile: " .. Database.GetActiveProfileName())
        instructions:SetText(
            "Paste exported profile JSON below. Importing replaces every category "
            .. "and emote in the current profile."
        )
        actionButton:SetText("Import Profile")
        SetStatus("")
        editBox:SetText("")
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        return true
    end

    exchangeDialog = dialog
    return dialog
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
        "Version " .. addon.VERSION .. "\n" ..
        "Author    Brandon Blackmoor\n" ..
        "Category  Roleplay\n" ..
        "License   GPL-3.0\n\n" ..

        "Slash Commands\n" ..
        "    /rpem - Show or hide the RP Emote Menu.\n" ..
        "    /rpem config - Open the addon settings.\n" ..
        "    /rpem options - Open the addon settings.\n" ..
        "    /rpem settings - Open the addon settings.\n\n" ..

        "Tokens supported by /e commands\n" ..
        "    {target}  Target's name without the realm.\n" ..
        "    {player}  Your character's name without the realm."
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

    resetAllCategoriesButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAllCategoriesButton:SetSize(260, 24)
    resetAllCategoriesButton:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -10)
    resetAllCategoriesButton:SetText("Reset All Categories and Emotes")
    resetAllCategoriesButton:SetEnabled(Database.CanEditActiveProfile())
    resetAllCategoriesButton:SetScript("OnClick", Database.ResetAllCategoriesToDefaults)

    return panel
end

local function CreateProfilesSettingsPanel()
    local panel = CreateFrame("Frame")

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("Profiles")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Choose a profile for this character, or create an editable copy of the defaults. " ..
        "The Default profile cannot be edited, renamed, or deleted."
    )
    description:SetTextColor(0.8, 0.8, 0.8)

    local currentProfileLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    currentProfileLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -80)
    currentProfileLabel:SetText("Current profile")

    local selector = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    selector:SetWidth(300)
    selector:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -100)
    selector:SetDefaultText(Database.GetActiveProfileName())

    local nameLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -150)
    nameLabel:SetText("New profile name")

    local nameInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    nameInput:SetSize(290, 24)
    nameInput:SetPoint("TOPLEFT", panel, "TOPLEFT", 26, -172)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(64)
    nameInput:SetFont(STANDARD_TEXT_FONT, 12, "")
    nameInput:SetTextColor(1, 1, 1, 1)

    local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -248)
    status:SetWidth(620)
    status:SetJustifyH("LEFT")

    local createButton
    local copyButton
    local renameButton
    local deleteButton
    local exportProfileButton
    local importProfileButton

    local function UpdateButtonState()
        local hasName = strtrim(nameInput:GetText() or "") ~= ""
        local editable = Database.CanEditActiveProfile()

        createButton:SetEnabled(hasName)
        copyButton:SetEnabled(hasName)
        renameButton:SetEnabled(hasName and editable)
        deleteButton:SetEnabled(editable)
        importProfileButton:SetEnabled(editable)
    end

    local function SetStatus(message, isError)
        status:SetText(message or "")

        if isError then
            status:SetTextColor(1, 0.35, 0.35, 1)
        else
            status:SetTextColor(0.35, 1, 0.45, 1)
        end
    end

    local function BuildProfileMenu(_, rootDescription)
        for _, profileName in ipairs(Database.GetProfileNames()) do
            rootDescription:CreateRadio(
                profileName,
                function()
                    return Database.GetActiveProfileName() == profileName
                end,
                function()
                    local success, errorMessage = Database.SetActiveProfile(profileName)

                    if success then
                        SetStatus("Using profile " .. profileName .. ".")
                    else
                        SetStatus(errorMessage, true)
                    end
                end
            )
        end
    end

    selector:SetupMenu(BuildProfileMenu)

    createButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    createButton:SetSize(125, 24)
    createButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -210)
    createButton:SetText("Create Profile")
    createButton:SetScript("OnClick", function()
        local success, result = Database.CreateProfile(nameInput:GetText())

        if success then
            nameInput:SetText("")
            SetStatus("Created profile " .. result .. ".")
            UpdateButtonState()
        else
            SetStatus(result, true)
        end
    end)

    copyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    copyButton:SetSize(125, 24)
    copyButton:SetPoint("LEFT", createButton, "RIGHT", 8, 0)
    copyButton:SetText("Copy Profile")
    copyButton:SetScript("OnClick", function()
        local success, result = Database.CopyProfile(
            Database.GetActiveProfileName(),
            nameInput:GetText()
        )

        if success then
            nameInput:SetText("")
            SetStatus("Copied profile to " .. result .. ".")
            UpdateButtonState()
        else
            SetStatus(result, true)
        end
    end)

    renameButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    renameButton:SetSize(125, 24)
    renameButton:SetPoint("LEFT", copyButton, "RIGHT", 8, 0)
    renameButton:SetText("Rename Profile")
    renameButton:SetScript("OnClick", function()
        local success, result = Database.RenameProfile(
            Database.GetActiveProfileName(),
            nameInput:GetText()
        )

        if success then
            nameInput:SetText("")
            SetStatus("Renamed profile to " .. result .. ".")
            UpdateButtonState()
        else
            SetStatus(result, true)
        end
    end)

    deleteButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    deleteButton:SetSize(125, 24)
    deleteButton:SetPoint("LEFT", renameButton, "RIGHT", 8, 0)
    deleteButton:SetText("Delete Profile")
    deleteButton:SetScript("OnClick", function()
        local profileName = Database.GetActiveProfileName()
        local success, errorMessage = Database.DeleteProfile(profileName)

        if success then
            SetStatus("Deleted profile " .. profileName .. ".")
        else
            SetStatus(errorMessage, true)
        end
    end)

    exportProfileButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    exportProfileButton:SetSize(125, 24)
    exportProfileButton:SetPoint("LEFT", selector, "RIGHT", 8, 0)
    exportProfileButton:SetText("Export Profile")
    exportProfileButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenProfileExport()
    end)

    importProfileButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    importProfileButton:SetSize(125, 24)
    importProfileButton:SetPoint("LEFT", exportProfileButton, "RIGHT", 8, 0)
    importProfileButton:SetText("Import Profile")
    importProfileButton:SetEnabled(Database.CanEditActiveProfile())
    importProfileButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenProfileImport()
    end)

    nameInput:SetScript("OnTextChanged", function(_, userInput)
        if userInput then
            UpdateButtonState()
        end
    end)

    nameInput:SetScript("OnEnterPressed", function(self)
        createButton:Click()
        self:ClearFocus()
    end)

    nameInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    panel.Refresh = function()
        selector:OverrideText(Database.GetActiveProfileName())
        UpdateButtonState()
    end

    panel:SetScript("OnShow", panel.Refresh)

    panel.Refresh()
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
    resetButton:SetText("Reset Category to Defaults")
    resetButton:SetEnabled(Database.CanEditActiveProfile())
    resetButton:SetScript("OnClick", function()
        Database.ResetCategoryToDefaults(categoryIndex)
    end)

    local importButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    importButton:SetSize(90, 24)
    importButton:SetText("Import")
    importButton:SetEnabled(Database.CanEditActiveProfile())
    importButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenImport(categoryIndex)
    end)

    local exportButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    exportButton:SetSize(90, 24)
    exportButton:SetPoint("TOPLEFT", content, "TOPLEFT", 196, -12)
    exportButton:SetText("Export")
    exportButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenExport(categoryIndex)
    end)

    importButton:SetPoint("LEFT", exportButton, "RIGHT", 8, 0)
    resetButton:SetPoint("LEFT", importButton, "RIGHT", 8, 0)

    local placeholderText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    placeholderText:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -50)
    placeholderText:SetWidth(630)
    placeholderText:SetJustifyH("LEFT")
    placeholderText:SetText(
        "{target} - Target's name without the realm.\n" ..
        "{player} - Your character's name without the realm.\n" ..
        "Targeted Command is used only when another unit is targeted.\n\n" ..
        "The Default profile cannot be edited."
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
        local editable = Database.CanEditActiveProfile()
        resetButton:SetEnabled(editable)
        importButton:SetEnabled(editable)

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
    local profilesPanel = CreateProfilesSettingsPanel()
    local categoryPanels = {}

    settingsCategory = Settings.RegisterCanvasLayoutCategory(aboutPanel, "RP Emote Menu")
    Settings.RegisterAddOnCategory(settingsCategory)

    generalSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        generalPanel,
        "General"
    )

    profilesSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        profilesPanel,
        "Profiles"
    )

    AddonSettings.RefreshProfiles = profilesPanel.Refresh

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
        if resetAllCategoriesButton then
            resetAllCategoriesButton:SetEnabled(Database.CanEditActiveProfile())
        end

        if exchangeDialog and exchangeDialog:IsShown() then
            exchangeDialog:UpdateActionState()
        end

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
