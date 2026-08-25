local _, addon = ...

addon.Settings = {}

local AddonSettings = addon.Settings
local MainWindow = addon.MainWindow
local Database = addon.Database
local Serialization = addon.Serialization
local settings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local SOURCE_URL = "https://github.com/bblackmoor/rpemotemenu"
local settingsCategory
local generalSettingsCategory
local appearanceSettingsCategory
local profilesSettingsCategory
local categoriesSettingsCategory
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

            if not self.emoteIndex
                and self.fieldName == "name"
                and AddonSettings.RefreshCategorySelector then
                AddonSettings.RefreshCategorySelector()
            end
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
            local canImport

            if self.dataType == "profile" then
                canImport = Database.ValidateNewProfileName(self.profileName) ~= nil
            else
                canImport = Database.CanEditActiveProfile()
            end

            actionButton:SetEnabled(canImport and hasText)
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
        local sourceProfileName

        if dialog.dataType == "profile" then
            success, result, sourceProfileName = Serialization.ImportProfileAsNew(
                dialog.profileName,
                editBox:GetText()
            )
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
                if dialog.onProfileImported then
                    dialog.onProfileImported()
                end

                SetStatus("Imported profile " .. sourceProfileName .. " as " .. result .. ".")
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
        self.profileName = nil
        self.onProfileImported = nil
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
        self.profileName = nil
        self.onProfileImported = nil
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
        self.profileName = nil
        self.onProfileImported = nil
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

    function dialog:OpenProfileImport(profileName, onProfileImported)
        local validName, errorMessage = Database.ValidateNewProfileName(profileName)
        if not validName then
            return false, errorMessage
        end

        self.mode = "import"
        self.dataType = "profile"
        self.categoryIndex = nil
        self.profileName = validName
        self.onProfileImported = onProfileImported
        title:SetText("Import New Profile: " .. validName)
        instructions:SetText(
            "Paste exported profile JSON below. Importing creates a new profile "
            .. "without changing the current profile."
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

    StaticPopupDialogs["RPEMOTEMENU_COPY_SOURCE"] = {
        text = "Press Ctrl+C to copy the source URL.",
        button1 = CLOSE or "Close",
        hasEditBox = true,
        maxLetters = 255,
        editBoxWidth = 340,
        OnShow = function(self, url)
            local editBox = self.GetEditBox and self:GetEditBox() or self.editBox

            editBox:SetText(url or self.data or SOURCE_URL)
            editBox:SetFocus()
            editBox:HighlightText()
        end,
        EditBoxOnEnterPressed = function(self)
            self:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("RP Emote Menu — About")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -12)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        "A customizable roleplaying emote menu with profiles, targeted " ..
        "commands, category and profile sharing, and adjustable fonts, " ..
        "colors, opacity, and inactivity fading."
    )

    local details = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    details:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -24)
    details:SetWidth(620)
    details:SetJustifyH("LEFT")
    details:SetText(
        "Version " .. addon.VERSION .. "\n" ..
        "Author    Brandon Blackmoor\n" ..
        "Category  Roleplay"
    )

    local sourceLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sourceLabel:SetPoint("TOPLEFT", details, "BOTTOMLEFT", 0, -2)
    sourceLabel:SetText("Source    ")

    local sourceLink = CreateFrame("Button", nil, panel)
    sourceLink:SetPoint("LEFT", sourceLabel, "RIGHT", 0, 0)

    local sourceText = sourceLink:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sourceText:SetPoint("LEFT", sourceLink, "LEFT")
    sourceText:SetText(SOURCE_URL)
    sourceText:SetTextColor(0.35, 0.7, 1, 1)

    sourceLink:SetSize(sourceText:GetStringWidth(), 16)
    sourceLink:SetScript("OnEnter", function()
        sourceText:SetTextColor(0.65, 0.85, 1, 1)
    end)
    sourceLink:SetScript("OnLeave", function()
        sourceText:SetTextColor(0.35, 0.7, 1, 1)
    end)
    sourceLink:SetScript("OnClick", function()
        StaticPopup_Show("RPEMOTEMENU_COPY_SOURCE", nil, nil, SOURCE_URL)
    end)

    local information = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    information:SetPoint("TOPLEFT", sourceLabel, "BOTTOMLEFT", 0, -2)
    information:SetWidth(620)
    information:SetJustifyH("LEFT")
    information:SetText(
        "License   GPL-3.0\n\n" ..

        "Slash commands\n" ..
        "    /rpem - Show or hide the RP Emote Menu.\n" ..
        "    /rpem config - Open the addon settings.\n" ..
        "    /rpem options - Open the addon settings.\n" ..
        "    /rpem settings - Open the addon settings.\n\n" ..

        "Character-name tokens\n" ..
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

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function CopyColor(color)
    return {
        r = color.r,
        g = color.g,
        b = color.b
    }
end

local function GetPickerColor(value, fallback)
    if type(value) ~= "table" then
        return CopyColor(fallback)
    end

    return {
        r = value.r or value[1] or fallback.r,
        g = value.g or value[2] or fallback.g,
        b = value.b or value[3] or fallback.b
    }
end

local function CreateNumberSetting(
    parent,
    labelText,
    settingKey,
    x,
    y,
    minimum,
    maximum,
    getValue,
    applyValue,
    suffix
)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)

    local editBox = CreateIntegerEditBox(
        parent,
        x,
        y - 22,
        70,
        getValue,
        function(value)
            applyValue(Clamp(value, minimum, maximum))
        end
    )
    editBox.settingKey = settingKey
    editBox.Label = label

    if suffix then
        local suffixLabel = parent:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )
        suffixLabel:SetPoint("LEFT", editBox, "RIGHT", 6, 0)
        suffixLabel:SetText(suffix)
        editBox.SuffixLabel = suffixLabel
    end

    return editBox
end

local function CreateColorSetting(
    parent,
    labelText,
    settingKey,
    x,
    y,
    getValue,
    applyValue
)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)

    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(52, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 22)
    button:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    button:SetBackdropColor(0.08, 0.08, 0.08, 1)
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    button.settingKey = settingKey

    button.Swatch = button:CreateTexture(nil, "ARTWORK")
    button.Swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    button.Swatch:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)

    button.RefreshValue = function(self)
        local color = getValue()
        self.Swatch:SetColorTexture(color.r, color.g, color.b, 1)
    end

    button:SetScript("OnClick", function(self)
        local originalColor = CopyColor(getValue())

        local function ApplyPickerColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            applyValue({r = r, g = g, b = b})
            self:RefreshValue()
        end

        ColorPickerFrame:SetupColorPickerAndShow({
            r = originalColor.r,
            g = originalColor.g,
            b = originalColor.b,
            swatchFunc = ApplyPickerColor,
            cancelFunc = function(previousColor)
                applyValue(GetPickerColor(previousColor, originalColor))
                self:RefreshValue()
            end
        })
    end)

    button:RefreshValue()
    return button
end

local function CreateFontSetting(parent, labelText, settingKey, x, y)
    local selectionGeneration = 0
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)

    local selector = CreateFrame(
        "DropdownButton",
        nil,
        parent,
        "WowStyle1DropdownTemplate"
    )
    selector:SetWidth(190)
    selector:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 21)
    selector.settingKey = settingKey

    selector.RefreshValue = function(self)
        self:OverrideText(settings[settingKey])
    end

    selector:SetupMenu(function(_, rootDescription)
        for _, font in ipairs(addon.GetAvailableFonts()) do
            local fontName = font.name

            rootDescription:CreateRadio(
                fontName,
                function() return settings[settingKey] == fontName end,
                function()
                    selectionGeneration = selectionGeneration + 1
                    local currentGeneration = selectionGeneration

                    settings[settingKey] = fontName
                    selector:RefreshValue()
                    MainWindow.ApplyAppearance()

                    local isCustomFont = true

                    for _, builtInFont in ipairs(addon.BuiltInFonts) do
                        if builtInFont.name == fontName then
                            isCustomFont = false
                            break
                        end
                    end

                    if isCustomFont then
                        for _, delay in ipairs({0.25, 0.75, 1.5, 3}) do
                            C_Timer.After(delay, function()
                                if selectionGeneration == currentGeneration then
                                    MainWindow.RefreshFont(settingKey, fontName)
                                end
                            end)
                        end
                    end
                end
            )
        end
    end)

    selector:RefreshValue()
    return selector
end

local function CreateAppearanceSettingsPanel()
    local panel = CreateFrame("Frame")
    local controls = {}

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("Fonts and Colors")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Customize the main menu for every profile. Changes appear immediately."
    )
    description:SetTextColor(0.8, 0.8, 0.8)

    local typographyHeading = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    typographyHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -82)
    typographyHeading:SetText("Typography")

    controls.categoryFont = CreateFontSetting(
        panel, "Category font", "categoryFont", 20, -112
    )

    controls.categoryFontSize = CreateNumberSetting(
        panel, "Size", "categoryFontSize", 230, -112, 8, 24,
        function() return settings.categoryFontSize end,
        function(value)
            settings.categoryFontSize = value
            MainWindow.ApplyAppearance()
        end,
        "px"
    )

    controls.emoteFont = CreateFontSetting(
        panel, "Emote font", "emoteFont", 330, -112
    )

    controls.emoteFontSize = CreateNumberSetting(
        panel, "Size", "emoteFontSize", 540, -112, 8, 24,
        function() return settings.emoteFontSize end,
        function(value)
            settings.emoteFontSize = value
            MainWindow.ApplyAppearance()
        end,
        "px"
    )

    local fontLoadingNote = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    fontLoadingNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -166)
    fontLoadingNote:SetWidth(620)
    fontLoadingNote:SetJustifyH("LEFT")
    fontLoadingNote:SetText(
        "Custom fonts may take |cffffff0010 to 30 seconds|r to appear the first time they are selected."
    )
    fontLoadingNote:SetTextColor(0.7, 0.7, 0.7)

    local colorsHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorsHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -190)
    colorsHeading:SetText("Colors")

    controls.categoryTextColor = CreateColorSetting(
        panel, "Category text", "categoryTextColor", 20, -218,
        function() return settings.categoryTextColor end,
        function(value)
            settings.categoryTextColor = value
            MainWindow.ApplyAppearance()
        end
    )

    controls.emoteTextColor = CreateColorSetting(
        panel, "Emote-label text", "emoteTextColor", 230, -218,
        function() return settings.emoteTextColor end,
        function(value)
            settings.emoteTextColor = value
            MainWindow.ApplyAppearance()
        end
    )

    controls.categoryHighlightColor = CreateColorSetting(
        panel, "Selected category", "categoryHighlightColor", 440, -218,
        function() return settings.categoryHighlightColor end,
        function(value)
            settings.categoryHighlightColor = value
            MainWindow.ApplyAppearance()
        end
    )

    controls.backgroundColor = CreateColorSetting(
        panel, "Background", "backgroundColor", 20, -273,
        function() return settings.backgroundColor end,
        function(value)
            settings.backgroundColor = value
            MainWindow.ApplyAppearance()
        end
    )

    controls.borderColor = CreateColorSetting(
        panel, "Border", "borderColor", 170, -273,
        function() return settings.borderColor end,
        function(value)
            settings.borderColor = value
            MainWindow.ApplyAppearance()
        end
    )

    local highlightEffectLabel = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )
    highlightEffectLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 320, -273)
    highlightEffectLabel:SetText("Selection effect")

    local highlightEffectSelector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    highlightEffectSelector:SetWidth(190)
    highlightEffectSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 320, -294)
    highlightEffectSelector:SetDefaultText("Background")
    highlightEffectSelector.settingKey = "categoryHighlightEffect"
    controls.categoryHighlightEffect = highlightEffectSelector

    controls.categoryHighlightThickness = CreateNumberSetting(
        panel, "Thickness", "categoryHighlightThickness", 540, -273, 1, 6,
        function() return settings.categoryHighlightThickness end,
        function(value)
            settings.categoryHighlightThickness = value
            MainWindow.ApplyAppearance()
        end,
        "px"
    )

    local highlightEffectLabels = {
        background = "Background",
        outline = "Outline",
        underline = "Underline",
        glow = "Glow",
        shadow = "Drop shadow"
    }

    local function RefreshHighlightControls()
        local usesThickness = settings.categoryHighlightEffect == "outline"
            or settings.categoryHighlightEffect == "underline"
        local thicknessControl = controls.categoryHighlightThickness

        thicknessControl:SetShown(usesThickness)
        thicknessControl.Label:SetShown(usesThickness)
        thicknessControl.SuffixLabel:SetShown(usesThickness)
        highlightEffectSelector:OverrideText(
            highlightEffectLabels[settings.categoryHighlightEffect]
        )
    end

    highlightEffectSelector:SetupMenu(function(_, rootDescription)
        for _, effect in ipairs({"background", "outline", "underline", "glow", "shadow"}) do
            rootDescription:CreateRadio(
                highlightEffectLabels[effect],
                function() return settings.categoryHighlightEffect == effect end,
                function()
                    settings.categoryHighlightEffect = effect
                    RefreshHighlightControls()
                    MainWindow.ApplyAppearance()
                end
            )
        end
    end)

    local windowHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    windowHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -327)
    windowHeading:SetText("Window")

    local borderLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -357)
    borderLabel:SetText("Border style")

    local borderSelector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    borderSelector:SetWidth(190)
    borderSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -378)
    borderSelector:SetDefaultText("Thin")
    borderSelector.settingKey = "borderStyle"
    controls.borderStyle = borderSelector

    local borderLabels = {
        none = "None",
        thin = "Thin",
        blizzard = "Blizzard"
    }

    local function BuildBorderMenu(_, rootDescription)
        for _, style in ipairs({"none", "thin", "blizzard"}) do
            rootDescription:CreateRadio(
                borderLabels[style],
                function() return settings.borderStyle == style end,
                function()
                    settings.borderStyle = style
                    borderSelector:OverrideText(borderLabels[style])
                    MainWindow.ApplyAppearance()
                end
            )
        end
    end

    borderSelector:SetupMenu(BuildBorderMenu)

    controls.backgroundOpacity = CreateNumberSetting(
        panel, "Background opacity", "backgroundOpacity", 330, -357, 0, 100,
        function() return settings.backgroundOpacity * 100 end,
        function(value)
            settings.backgroundOpacity = value / 100
            MainWindow.ApplyAppearance()
        end,
        "%"
    )

    controls.windowOpacity = CreateNumberSetting(
        panel, "Active window opacity", "windowOpacity", 20, -437, 10, 100,
        function() return settings.windowOpacity * 100 end,
        function(value)
            settings.windowOpacity = value / 100
            settings.inactiveOpacity = math.min(
                settings.inactiveOpacity,
                settings.windowOpacity
            )
            MainWindow.ApplyAppearance()
        end,
        "%"
    )

    controls.inactiveOpacity = CreateNumberSetting(
        panel, "Inactive opacity", "inactiveOpacity", 330, -437, 10, 100,
        function() return settings.inactiveOpacity * 100 end,
        function(value)
            settings.inactiveOpacity = math.min(
                value / 100,
                settings.windowOpacity
            )
            MainWindow.ApplyFadeSettings()
        end,
        "%"
    )

    local fadeCheckbox = CreateCheckbox(
        panel,
        "Fade the menu when inactive",
        -507,
        function() return settings.fadeEnabled end,
        function(value)
            settings.fadeEnabled = value
            MainWindow.ApplyFadeSettings()
        end
    )
    fadeCheckbox.settingKey = "fadeEnabled"
    controls.fadeEnabled = fadeCheckbox

    controls.fadeDelay = CreateNumberSetting(
        panel, "Fade after", "fadeDelay", 20, -552, 0, 60,
        function() return settings.fadeDelay end,
        function(value)
            settings.fadeDelay = value
            MainWindow.ApplyFadeSettings()
        end,
        "seconds"
    )

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(190, 24)
    resetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 330, -574)
    resetButton:SetText("Reset Appearance")
    resetButton.settingKey = "resetAppearance"
    controls.resetAppearance = resetButton

    local appearanceKeys = {
        "categoryFont",
        "emoteFont",
        "categoryFontSize",
        "emoteFontSize",
        "categoryTextColor",
        "emoteTextColor",
        "categoryHighlightColor",
        "categoryHighlightEffect",
        "categoryHighlightThickness",
        "backgroundColor",
        "borderColor",
        "borderStyle",
        "backgroundOpacity",
        "windowOpacity",
        "fadeEnabled",
        "fadeDelay",
        "inactiveOpacity"
    }

    local function RefreshControls()
        for key, control in pairs(controls) do
            if control.RefreshValue then
                control:RefreshValue()
            end
        end

        RefreshHighlightControls()
        borderSelector:OverrideText(borderLabels[settings.borderStyle])
        fadeCheckbox:SetChecked(settings.fadeEnabled)
    end

    resetButton:SetScript("OnClick", function()
        for _, key in ipairs(appearanceKeys) do
            local value = addon.DefaultSettings[key]

            if type(value) == "table" then
                settings[key] = CopyColor(value)
            else
                settings[key] = value
            end
        end

        RefreshControls()
        MainWindow.ApplyAppearance()
    end)

    panel.RefreshControls = RefreshControls
    panel.appearanceControls = controls
    panel:SetScript("OnShow", RefreshControls)
    RefreshControls()
    return panel
end

local function CreateGeneralSettingsPanel()
    local panel = CreateFrame("Frame")

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("General")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetText("Configure window visibility, movement, resizing, and login behavior.")
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

    local sidebarWidthLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sidebarWidthLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -290)
    sidebarWidthLabel:SetText("Left column width")

    local sidebarWidthBox = CreateIntegerEditBox(
        panel, 190, -286, 70,
        function() return settings.sidebarWidth end,
        MainWindow.ApplySidebarWidth
    )

    local sidebarWidthSuffix = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    sidebarWidthSuffix:SetPoint("LEFT", sidebarWidthBox, "RIGHT", 6, 0)
    sidebarWidthSuffix:SetText("px")

    AddonSettings.RefreshGeneralWindowFields = function()
        positionXBox:RefreshValue()
        positionYBox:RefreshValue()
        widthBox:RefreshValue()
        heightBox:RefreshValue()
        sidebarWidthBox:RefreshValue()
    end

    panel:SetScript("OnShow", AddonSettings.RefreshGeneralWindowFields)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(290, 24)
    resetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -335)
    resetButton:SetText("Reset Window Position, Size, and Column")
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
        "Choose a profile for this character, create or copy an editable profile, " ..
        "or import a new one. The Default profile cannot be edited, renamed, or deleted."
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
    nameLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -175)
    nameLabel:SetText("New profile name")

    local nameInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    nameInput:SetSize(290, 24)
    nameInput:SetPoint("TOPLEFT", panel, "TOPLEFT", 26, -197)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(64)
    nameInput:SetFont(STANDARD_TEXT_FONT, 12, "")
    nameInput:SetTextColor(1, 1, 1, 1)

    local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -273)
    status:SetWidth(620)
    status:SetJustifyH("LEFT")

    local createButton
    local copyButton
    local renameButton
    local deleteButton
    local exportProfileButton
    local importProfileButton

    local function UpdateButtonState()
        local editable = Database.CanEditActiveProfile()
        local validNewProfileName = Database.ValidateNewProfileName(nameInput:GetText())

        createButton:SetEnabled(validNewProfileName ~= nil)
        copyButton:SetEnabled(validNewProfileName ~= nil)
        renameButton:SetEnabled(editable)
        deleteButton:SetEnabled(editable)
        importProfileButton:SetEnabled(validNewProfileName ~= nil)
    end

    local function SetStatus(message, isError)
        status:SetText(message or "")

        if isError then
            status:SetTextColor(1, 0.35, 0.35, 1)
        else
            status:SetTextColor(0.35, 1, 0.45, 1)
        end
    end

    local function GetPopupEditBox(popup)
        return popup.GetEditBox and popup:GetEditBox() or popup.editBox
    end

    local function GetPopupButton1(popup)
        return popup.GetButton1 and popup:GetButton1() or popup.button1
    end

    StaticPopupDialogs["RPEMOTEMENU_RENAME_PROFILE"] = {
        text = 'Rename the profile "%s".',
        button1 = "Rename",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        maxLetters = 64,
        editBoxWidth = 260,
        OnShow = function(self, profileName)
            local editBox = GetPopupEditBox(self)

            editBox:SetText(profileName or self.data)
            editBox:HighlightText()
            editBox:SetFocus()
            GetPopupButton1(self):SetEnabled(false)
        end,
        OnAccept = function(self, profileName)
            local success, result = Database.RenameProfile(
                profileName,
                GetPopupEditBox(self):GetText()
            )

            if success then
                SetStatus("Renamed profile to " .. result .. ".")
            else
                SetStatus(result, true)
            end
        end,
        EditBoxOnTextChanged = function(self)
            local popup = self:GetParent()
            local validName = Database.ValidateNewProfileName(
                self:GetText(),
                popup.data
            )

            GetPopupButton1(popup):SetEnabled(validName ~= nil)
        end,
        EditBoxOnEnterPressed = function(self)
            local popup = self:GetParent()
            local acceptButton = GetPopupButton1(popup)

            if acceptButton:IsEnabled() then
                acceptButton:Click()
            end
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_DELETE_PROFILE"] = {
        text = 'Delete the profile "%s"?\n\nCharacters using it will return to Default.',
        button1 = DELETE or "Delete",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, profileName)
            local success, errorMessage = Database.DeleteProfile(profileName)

            if success then
                SetStatus("Deleted profile " .. profileName .. ".")
            else
                SetStatus(errorMessage, true)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

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
    createButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -235)
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
    renameButton:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -8)
    renameButton:SetText("Rename Profile")
    renameButton:SetScript("OnClick", function()
        local profileName = Database.GetActiveProfileName()

        if not Database.CanEditActiveProfile() then
            return
        end

        StaticPopup_Show("RPEMOTEMENU_RENAME_PROFILE", profileName, nil, profileName)
    end)

    deleteButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    deleteButton:SetSize(125, 24)
    deleteButton:SetPoint("LEFT", renameButton, "RIGHT", 8, 0)
    deleteButton:SetText("Delete Profile")
    deleteButton:SetScript("OnClick", function()
        local profileName = Database.GetActiveProfileName()

        if not Database.CanEditActiveProfile() then
            return
        end

        StaticPopup_Show("RPEMOTEMENU_DELETE_PROFILE", profileName, nil, profileName)
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
    importProfileButton:SetPoint("LEFT", nameInput, "RIGHT", 12, 0)
    importProfileButton:SetText("Import Profile")
    importProfileButton:SetEnabled(false)
    importProfileButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenProfileImport(nameInput:GetText(), function()
            nameInput:SetText("")
            UpdateButtonState()
        end)
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

local function CreateCategoriesSettingsPanel()
    local panel = CreateFrame("Frame")
    local selectedCategoryIndex = settings.selectedCategory

    if type(selectedCategoryIndex) ~= "number"
        or selectedCategoryIndex < 1
        or selectedCategoryIndex > MAX_CATEGORIES then
        selectedCategoryIndex = 1
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 4)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(700, 1500)
    scrollFrame:SetScrollChild(content)

    local heading = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
    heading:SetText("Categories")

    local selector = CreateFrame(
        "DropdownButton",
        nil,
        content,
        "WowStyle1DropdownTemplate"
    )
    selector:SetWidth(300)
    selector:SetPoint("TOPLEFT", content, "TOPLEFT", 196, -12)

    local function GetCategoryLabel(categoryIndex)
        local category = Database.GetCategory(categoryIndex)
        local categoryName = strtrim(category and category.name or "")
        local label = "Category " .. categoryIndex

        if categoryName ~= "" then
            label = label .. ": " .. categoryName
        end

        return label
    end

    selector:SetDefaultText(GetCategoryLabel(selectedCategoryIndex))

    local resetButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetButton:SetSize(190, 24)
    resetButton:SetText("Reset Category to Defaults")
    resetButton:SetEnabled(Database.CanEditActiveProfile())
    resetButton:SetScript("OnClick", function()
        Database.ResetCategoryToDefaults(selectedCategoryIndex)
    end)

    local importButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    importButton:SetSize(90, 24)
    importButton:SetText("Import")
    importButton:SetEnabled(Database.CanEditActiveProfile())
    importButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenImport(selectedCategoryIndex)
    end)

    local exportButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    exportButton:SetSize(90, 24)
    exportButton:SetPoint("TOPLEFT", content, "TOPLEFT", 196, -48)
    exportButton:SetText("Export")
    exportButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenExport(selectedCategoryIndex)
    end)

    importButton:SetPoint("LEFT", exportButton, "RIGHT", 8, 0)
    resetButton:SetPoint("LEFT", importButton, "RIGHT", 8, 0)

    local placeholderText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    placeholderText:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -86)
    placeholderText:SetWidth(630)
    placeholderText:SetJustifyH("LEFT")
    placeholderText:SetText(
        "Named categories appear in the sidebar; blank categories stay hidden.\n" ..
        "{target} - Target's name without the realm.\n" ..
        "{player} - Your character's name without the realm.\n" ..
        "Targeted Command is used only when another unit is targeted.\n" ..
        "Import replaces this category. The Default profile cannot be edited."
    )
    placeholderText:SetTextColor(0.8, 0.8, 0.8)

    local editors = {}
    local y = -162

    local nameBox = CreateLabeledEditBox(
        content,
        "Category Name",
        16,
        y,
        420,
        selectedCategoryIndex,
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
            selectedCategoryIndex,
            emoteIndex,
            "label"
        )

        local defaultBox = CreateLabeledEditBox(
            content,
            "Default Command",
            48,
            y - 48,
            390,
            selectedCategoryIndex,
            emoteIndex,
            "defaultCommand"
        )

        local targetedBox = CreateLabeledEditBox(
            content,
            "Targeted Command (optional)",
            48,
            y - 76,
            390,
            selectedCategoryIndex,
            emoteIndex,
            "targetedCommand"
        )

        table.insert(editors, labelBox)
        table.insert(editors, defaultBox)
        table.insert(editors, targetedBox)

        y = y - 116
    end

    content:SetHeight(-y + 20)

    local function RefreshCategorySelector()
        selector:OverrideText(GetCategoryLabel(selectedCategoryIndex))
    end

    local function SelectCategory(categoryIndex)
        if type(categoryIndex) ~= "number"
            or categoryIndex < 1
            or categoryIndex > MAX_CATEGORIES then
            return
        end

        selectedCategoryIndex = categoryIndex

        for _, editBox in ipairs(editors) do
            editBox.categoryIndex = categoryIndex
        end

        scrollFrame:SetVerticalScroll(0)
        panel.RefreshEditors()
    end

    selector:SetupMenu(function(_, rootDescription)
        for categoryIndex = 1, MAX_CATEGORIES do
            rootDescription:CreateRadio(
                GetCategoryLabel(categoryIndex),
                function()
                    return selectedCategoryIndex == categoryIndex
                end,
                function()
                    SelectCategory(categoryIndex)
                end
            )
        end
    end)

    panel.RefreshEditors = function(changedCategoryIndex)
        if changedCategoryIndex
            and changedCategoryIndex ~= selectedCategoryIndex then
            return
        end

        local editable = Database.CanEditActiveProfile()
        resetButton:SetEnabled(editable)
        importButton:SetEnabled(editable)

        for _, editBox in ipairs(editors) do
            editBox:RefreshFromDatabase()
        end

        RefreshCategorySelector()
    end

    panel:SetScript("OnShow", function(self)
        self.RefreshEditors()
    end)

    panel.categorySelector = selector
    panel.SelectCategory = SelectCategory
    panel.GetSelectedCategory = function()
        return selectedCategoryIndex
    end
    AddonSettings.RefreshCategorySelector = RefreshCategorySelector

    return panel
end

function AddonSettings.CreateSettingsPanel()
    settings = Database.GetSettings()
    local aboutPanel = CreateAboutPanel()
    local generalPanel = CreateGeneralSettingsPanel()
    local appearancePanel = CreateAppearanceSettingsPanel()
    local profilesPanel = CreateProfilesSettingsPanel()
    local categoriesPanel = CreateCategoriesSettingsPanel()

    settingsCategory = Settings.RegisterCanvasLayoutCategory(aboutPanel, "RP Emote Menu")
    Settings.RegisterAddOnCategory(settingsCategory)

    generalSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        generalPanel,
        "General"
    )

    appearanceSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        appearancePanel,
        "Fonts and Colors"
    )

    profilesSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        profilesPanel,
        "Profiles"
    )

    AddonSettings.RefreshProfiles = profilesPanel.Refresh

    categoriesSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        categoriesPanel,
        "Categories"
    )

    AddonSettings.RefreshEditors = function(categoryIndex)
        if resetAllCategoriesButton then
            resetAllCategoriesButton:SetEnabled(Database.CanEditActiveProfile())
        end

        if exchangeDialog and exchangeDialog:IsShown() then
            exchangeDialog:UpdateActionState()
        end

        categoriesPanel.RefreshEditors(categoryIndex)
    end
end

AddonSettings.OpenAbout = function()
    if settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end

AddonSettings.Open = function()
    if generalSettingsCategory then
        Settings.OpenToCategory(generalSettingsCategory:GetID())
    elseif settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end
