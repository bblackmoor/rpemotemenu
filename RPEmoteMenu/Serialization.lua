local _, addon = ...

local Serialization = {}
addon.Serialization = Serialization

local Database = addon.Database
local JSON = addon.JSON
local FORMAT_NAME = "RPEmoteMenu"
local FORMAT_VERSION = 1
local DEFAULT_PROFILE_NAME = "Default"
local MAX_DOCUMENT_BYTES = 4 * 1024 * 1024
local MAX_PROFILE_NAME_LENGTH = 64
local MAX_CATEGORY_NAME_LENGTH = 128
local MAX_LABEL_LENGTH = 128
local MAX_COMMAND_LENGTH = 4096
local MAX_FONT_NAME_LENGTH = 128
local MAX_CHARACTER_KEY_LENGTH = 256

local CATEGORY_DOCUMENT_FIELDS = {
    format = true, version = true, type = true, name = true, emotes = true
}
local PROFILE_DOCUMENT_FIELDS = {
    format = true, version = true, type = true, name = true, categories = true
}
local SETTINGS_DOCUMENT_FIELDS = {
    format = true, version = true, type = true, settings = true
}
local BACKUP_DOCUMENT_FIELDS = {
    format = true,
    version = true,
    type = true,
    settings = true,
    profiles = true,
    activeProfiles = true
}
local PROFILE_FIELDS = {name = true, categories = true}
local CATEGORY_FIELDS = {name = true, emotes = true}
local EMOTE_FIELDS = {label = true, defaultCommand = true, targetedCommand = true}

local SETTINGS_FIELDS = {
    locked = true,
    hideSettingsGear = true,
    showAtLogin = true,
    rememberMinimized = true,
    width = true,
    height = true,
    sidebarWidth = true,
    categoryFont = true,
    emoteFont = true,
    categoryFontSize = true,
    emoteFontSize = true,
    categoryTextColor = true,
    selectedCategoryTextColor = true,
    emoteTextColor = true,
    categoryHighlightColor = true,
    categoryHighlightEffect = true,
    categoryHighlightThickness = true,
    backgroundColor = true,
    borderColor = true,
    borderStyle = true,
    backgroundOpacity = true,
    windowOpacity = true,
    fadeEnabled = true,
    fadeDelay = true,
    inactiveOpacity = true,
    x = true,
    y = true
}

local BOOLEAN_SETTING_KEYS = {
    "locked",
    "hideSettingsGear",
    "showAtLogin",
    "rememberMinimized",
    "fadeEnabled"
}

local COLOR_SETTING_KEYS = {
    "categoryTextColor",
    "selectedCategoryTextColor",
    "emoteTextColor",
    "categoryHighlightColor",
    "backgroundColor",
    "borderColor"
}

local VALID_CATEGORY_HIGHLIGHT_EFFECTS = {
    background = true, outline = true, underline = true, shadow = true
}
local VALID_BORDER_STYLES = {none = true, thin = true, blizzard = true}

local function ValidateObject(value, allowedFields, description)
    if type(value) ~= "table" or JSON.IsArray(value) or value == JSON.Null then
        return nil, description .. " must be an object."
    end

    for key in pairs(value) do
        if not allowedFields[key] then
            return nil, description .. " contains an unsupported field: " .. tostring(key) .. "."
        end
    end

    return true
end

local function ValidateString(value, maximumLength, description)
    if type(value) ~= "string" then
        return nil, description .. " must be a string."
    end
    if #value > maximumLength then
        return nil, description .. " exceeds " .. maximumLength .. " characters."
    end
    return value
end

local function ValidateBoolean(value, description)
    if type(value) ~= "boolean" then
        return nil, description .. " must be true or false."
    end
    return value
end

local function ValidateNumber(value, minimum, maximum, description, integer)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge then
        return nil, description .. " must be a number."
    end
    if integer and value % 1 ~= 0 then
        return nil, description .. " must be a whole number."
    end
    if value < minimum or value > maximum then
        return nil, description .. " must be between " .. minimum .. " and " .. maximum .. "."
    end
    return value
end

local function ValidateColor(value, description)
    local valid, errorMessage = ValidateObject(
        value,
        {r = true, g = true, b = true},
        description
    )
    if not valid then
        return nil, errorMessage
    end

    local color = {}
    for _, component in ipairs({"r", "g", "b"}) do
        color[component], errorMessage = ValidateNumber(
            value[component], 0, 1, description .. " " .. component, false
        )
        if color[component] == nil then
            return nil, errorMessage
        end
    end

    return color
end

local function CopyColor(value)
    return {r = value.r, g = value.g, b = value.b}
end

local function BlankEmote()
    return {label = "", defaultCommand = "", targetedCommand = ""}
end

local function ValidateEmote(value, index, prefix)
    local description = (prefix or "Emote") .. " " .. index
    local valid, errorMessage = ValidateObject(value, EMOTE_FIELDS, description)
    if not valid then
        return nil, errorMessage
    end

    local label
    label, errorMessage = ValidateString(value.label, MAX_LABEL_LENGTH, description .. " label")
    if not label then
        return nil, errorMessage
    end

    local defaultCommand
    defaultCommand, errorMessage = ValidateString(
        value.defaultCommand,
        MAX_COMMAND_LENGTH,
        description .. " default command"
    )
    if not defaultCommand then
        return nil, errorMessage
    end

    local targetedCommand = value.targetedCommand
    if targetedCommand == nil then
        targetedCommand = ""
    else
        targetedCommand, errorMessage = ValidateString(
            targetedCommand,
            MAX_COMMAND_LENGTH,
            description .. " targeted command"
        )
        if not targetedCommand then
            return nil, errorMessage
        end
    end

    return {
        label = label,
        defaultCommand = defaultCommand,
        targetedCommand = targetedCommand
    }
end

local function ValidateCategory(value, description, allowedFields)
    local valid, errorMessage = ValidateObject(
        value,
        allowedFields or CATEGORY_FIELDS,
        description
    )
    if not valid then
        return nil, errorMessage
    end

    local name
    name, errorMessage = ValidateString(value.name, MAX_CATEGORY_NAME_LENGTH, description .. " name")
    if not name then
        return nil, errorMessage
    end

    if not JSON.IsArray(value.emotes) then
        return nil, description .. " emotes must be an array."
    end
    if #value.emotes > addon.MAX_EMOTES then
        return nil, description .. " cannot contain more than " .. addon.MAX_EMOTES .. " emotes."
    end

    local category = {name = name, emotes = {}}
    for index = 1, addon.MAX_EMOTES do
        if index <= #value.emotes then
            local emote
            emote, errorMessage = ValidateEmote(
                value.emotes[index], index, description .. " emote"
            )
            if not emote then
                return nil, errorMessage
            end
            category.emotes[index] = emote
        else
            category.emotes[index] = BlankEmote()
        end
    end

    return category
end

local function ValidateCategories(value, description)
    if not JSON.IsArray(value) then
        return nil, description .. " categories must be an array."
    end
    if #value == 0 or #value > addon.MAX_CATEGORIES then
        return nil, description .. " must contain between 1 and "
            .. addon.MAX_CATEGORIES .. " categories."
    end

    local categories = {}
    local errorMessage
    for index = 1, addon.MAX_CATEGORIES do
        if index <= #value then
            categories[index], errorMessage = ValidateCategory(
                value[index], description .. " category " .. index
            )
            if not categories[index] then
                return nil, errorMessage
            end
        else
            local emotes = {}
            for emoteIndex = 1, addon.MAX_EMOTES do
                emotes[emoteIndex] = BlankEmote()
            end
            categories[index] = {name = "", emotes = emotes}
        end
    end

    return categories
end

local function ValidateProfile(value, description, allowedFields)
    local valid, errorMessage = ValidateObject(
        value, allowedFields or PROFILE_FIELDS, description
    )
    if not valid then
        return nil, errorMessage
    end

    local profileName
    profileName, errorMessage = ValidateString(
        value.name, MAX_PROFILE_NAME_LENGTH, description .. " name"
    )
    if not profileName then
        return nil, errorMessage
    end
    if profileName == "" then
        return nil, description .. " name cannot be empty."
    end

    local categories
    categories, errorMessage = ValidateCategories(value.categories, description)
    if not categories then
        return nil, errorMessage
    end

    return {name = profileName, categories = categories}
end

local function ValidateSettings(value)
    local valid, errorMessage = ValidateObject(value, SETTINGS_FIELDS, "Settings")
    if not valid then
        return nil, errorMessage
    end

    local imported = {}
    for _, key in ipairs(BOOLEAN_SETTING_KEYS) do
        imported[key], errorMessage = ValidateBoolean(value[key], "Setting " .. key)
        if imported[key] == nil then
            return nil, errorMessage
        end
    end

    imported.width, errorMessage = ValidateNumber(value.width, 250, 600, "Window width", true)
    if not imported.width then return nil, errorMessage end
    imported.height, errorMessage = ValidateNumber(value.height, 150, 600, "Window height", true)
    if not imported.height then return nil, errorMessage end
    imported.sidebarWidth, errorMessage = ValidateNumber(
        value.sidebarWidth,
        addon.MIN_SIDEBAR_WIDTH,
        addon.MAX_SIDEBAR_WIDTH,
        "Left column width",
        true
    )
    if not imported.sidebarWidth then return nil, errorMessage end

    for _, key in ipairs({"categoryFont", "emoteFont"}) do
        imported[key], errorMessage = ValidateString(
            value[key], MAX_FONT_NAME_LENGTH, "Setting " .. key
        )
        if not imported[key] then
            return nil, errorMessage
        end
        if imported[key] == "" then
            return nil, "Setting " .. key .. " cannot be empty."
        end
    end

    imported.categoryFontSize, errorMessage = ValidateNumber(
        value.categoryFontSize, 8, 24, "Category font size", true
    )
    if not imported.categoryFontSize then return nil, errorMessage end
    imported.emoteFontSize, errorMessage = ValidateNumber(
        value.emoteFontSize, 8, 24, "Emote font size", true
    )
    if not imported.emoteFontSize then return nil, errorMessage end

    for _, key in ipairs(COLOR_SETTING_KEYS) do
        imported[key], errorMessage = ValidateColor(value[key], "Setting " .. key)
        if not imported[key] then
            return nil, errorMessage
        end
    end

    if not VALID_CATEGORY_HIGHLIGHT_EFFECTS[value.categoryHighlightEffect] then
        return nil, "Setting categoryHighlightEffect is not supported."
    end
    imported.categoryHighlightEffect = value.categoryHighlightEffect
    imported.categoryHighlightThickness, errorMessage = ValidateNumber(
        value.categoryHighlightThickness, 1, 6, "Selection thickness", true
    )
    if not imported.categoryHighlightThickness then return nil, errorMessage end

    if not VALID_BORDER_STYLES[value.borderStyle] then
        return nil, "Setting borderStyle is not supported."
    end
    imported.borderStyle = value.borderStyle

    imported.backgroundOpacity, errorMessage = ValidateNumber(
        value.backgroundOpacity, 0, 1, "Background opacity", false
    )
    if imported.backgroundOpacity == nil then return nil, errorMessage end
    imported.windowOpacity, errorMessage = ValidateNumber(
        value.windowOpacity, 0.1, 1, "Active window opacity", false
    )
    if not imported.windowOpacity then return nil, errorMessage end
    imported.fadeDelay, errorMessage = ValidateNumber(
        value.fadeDelay, 0, 60, "Fade delay", true
    )
    if imported.fadeDelay == nil then return nil, errorMessage end
    imported.inactiveOpacity, errorMessage = ValidateNumber(
        value.inactiveOpacity, 0.1, 1, "Inactive opacity", false
    )
    if not imported.inactiveOpacity then return nil, errorMessage end
    if imported.inactiveOpacity > imported.windowOpacity then
        return nil, "Inactive opacity cannot exceed active window opacity."
    end

    if (value.x == nil) ~= (value.y == nil) then
        return nil, "Window position must contain both x and y."
    end
    if value.x ~= nil then
        imported.x, errorMessage = ValidateNumber(
            value.x, -100000, 100000, "Window position x", true
        )
        if imported.x == nil then return nil, errorMessage end
        imported.y, errorMessage = ValidateNumber(
            value.y, -100000, 100000, "Window position y", true
        )
        if imported.y == nil then return nil, errorMessage end
    end

    return imported
end

local function ExportCategoryData(category)
    local emotes = JSON.Array()
    local lastPopulated = 0
    for index = 1, addon.MAX_EMOTES do
        local emote = category.emotes[index]
        if emote.label ~= ""
            or emote.defaultCommand ~= ""
            or emote.targetedCommand ~= "" then
            lastPopulated = index
        end
    end

    for index = 1, lastPopulated do
        local source = category.emotes[index]
        local emote = {label = source.label, defaultCommand = source.defaultCommand}
        if source.targetedCommand ~= "" then
            emote.targetedCommand = source.targetedCommand
        end
        emotes[index] = emote
    end

    return {name = category.name, emotes = emotes}
end

local function ExportProfileData(profileName, categories)
    local exportedCategories = JSON.Array()
    for index = 1, addon.MAX_CATEGORIES do
        exportedCategories[index] = ExportCategoryData(categories[index])
    end
    return {name = profileName, categories = exportedCategories}
end

local function ExportSettingsData(includeWindowPosition)
    local source = Database.GetSettings()
    local exported = {}

    for _, key in ipairs(BOOLEAN_SETTING_KEYS) do
        exported[key] = source[key]
    end
    for _, key in ipairs({
        "width", "height", "sidebarWidth",
        "categoryFont", "emoteFont", "categoryFontSize", "emoteFontSize",
        "categoryHighlightEffect", "categoryHighlightThickness", "borderStyle",
        "backgroundOpacity", "windowOpacity", "fadeDelay", "inactiveOpacity"
    }) do
        exported[key] = source[key]
    end
    for _, key in ipairs(COLOR_SETTING_KEYS) do
        exported[key] = CopyColor(source[key])
    end
    if includeWindowPosition then
        exported.x = source.x
        exported.y = source.y
    end

    return exported
end

local function IsValidCategoryIndex(categoryIndex)
    return type(categoryIndex) == "number"
        and categoryIndex % 1 == 0
        and categoryIndex >= 1
        and categoryIndex <= addon.MAX_CATEGORIES
end

local function ApplyImportedSettings(imported)
    local destination = Database.GetSettings()
    for key, value in pairs(imported) do
        destination[key] = type(value) == "table" and CopyColor(value) or value
    end

    if addon.MainWindow and addon.MainWindow.GetFrame
        and addon.MainWindow.GetFrame() then
        addon.MainWindow.ApplyWindowGeometry(
            destination.x, destination.y, destination.width, destination.height
        )
        addon.MainWindow.ApplySidebarWidth(destination.sidebarWidth)
        addon.MainWindow.ApplyMovementLock()
        addon.MainWindow.ApplySettingsGearVisibility()
        addon.MainWindow.ApplyAppearance()
    end
    if addon.Settings and addon.Settings.RefreshSettingsPanels then
        addon.Settings.RefreshSettingsPanels()
    end
end

function Serialization.ExportCategory(categoryIndex)
    if not IsValidCategoryIndex(categoryIndex) then
        return nil, "Choose a valid category to export."
    end
    local result = ExportCategoryData(Database.GetCategory(categoryIndex))
    result.format = FORMAT_NAME
    result.version = FORMAT_VERSION
    result.type = "category"
    return JSON.Encode(result, true)
end

function Serialization.ExportProfile()
    local result = ExportProfileData(
        Database.GetActiveProfileName(), Database.GetCategories()
    )
    result.format = FORMAT_NAME
    result.version = FORMAT_VERSION
    result.type = "profile"
    return JSON.Encode(result, true)
end

function Serialization.ExportSettings(includeWindowPosition)
    return JSON.Encode({
        format = FORMAT_NAME,
        version = FORMAT_VERSION,
        type = "settings",
        settings = ExportSettingsData(includeWindowPosition == true)
    }, true)
end

function Serialization.ExportBackup(includeWindowPosition)
    local database = Database.GetSettings()
    local profileNames = {}
    for profileName in pairs(database.profiles) do
        if profileName ~= DEFAULT_PROFILE_NAME then
            profileNames[#profileNames + 1] = profileName
        end
    end
    table.sort(profileNames, function(first, second)
        return string.lower(first) < string.lower(second)
    end)

    local profiles = JSON.Array()
    for index, profileName in ipairs(profileNames) do
        profiles[index] = ExportProfileData(
            profileName, database.profiles[profileName].categories
        )
    end

    local activeProfiles = {}
    for characterKey, profileName in pairs(database.activeProfiles) do
        if profileName == DEFAULT_PROFILE_NAME or database.profiles[profileName] then
            activeProfiles[characterKey] = profileName
        end
    end

    return JSON.Encode({
        format = FORMAT_NAME,
        version = FORMAT_VERSION,
        type = "backup",
        settings = ExportSettingsData(includeWindowPosition == true),
        profiles = profiles,
        activeProfiles = activeProfiles
    }, true)
end

function Serialization.Decode(text, expectedType)
    if type(text) ~= "string" or text == "" then
        return nil, "Paste exported RP Emote Menu data."
    end
    if #text > MAX_DOCUMENT_BYTES then
        return nil, "The imported data exceeds the maximum supported size."
    end

    local value, errorMessage = JSON.Decode(text)
    if not value then
        return nil, "Invalid JSON: " .. errorMessage
    end
    if type(value) ~= "table" or JSON.IsArray(value) or value == JSON.Null then
        return nil, "Import data must be an object."
    end
    if value.format ~= FORMAT_NAME then
        return nil, "This data was not exported by RP Emote Menu."
    end
    if value.version ~= FORMAT_VERSION then
        return nil, "This import format version is not supported."
    end
    if value.type ~= "category"
        and value.type ~= "profile"
        and value.type ~= "settings"
        and value.type ~= "backup" then
        return nil, "The import data has an unsupported type."
    end
    if expectedType and value.type ~= expectedType then
        return nil, "This is " .. value.type .. " data, not " .. expectedType .. " data."
    end

    local valid
    if value.type == "category" then
        local category
        category, errorMessage = ValidateCategory(
            value, "Category", CATEGORY_DOCUMENT_FIELDS
        )
        if not category then return nil, errorMessage end
        return {type = "category", name = category.name, category = category}
    end

    if value.type == "profile" then
        local profile
        profile, errorMessage = ValidateProfile(
            value, "Profile", PROFILE_DOCUMENT_FIELDS
        )
        if not profile then return nil, errorMessage end
        profile.type = "profile"
        return profile
    end

    if value.type == "settings" then
        valid, errorMessage = ValidateObject(
            value, SETTINGS_DOCUMENT_FIELDS, "Import data"
        )
        if not valid then return nil, errorMessage end

        local importedSettings
        importedSettings, errorMessage = ValidateSettings(value.settings)
        if not importedSettings then return nil, errorMessage end
        return {type = "settings", settings = importedSettings}
    end

    valid, errorMessage = ValidateObject(
        value, BACKUP_DOCUMENT_FIELDS, "Import data"
    )
    if not valid then return nil, errorMessage end

    local importedSettings
    importedSettings, errorMessage = ValidateSettings(value.settings)
    if not importedSettings then return nil, errorMessage end
    if not JSON.IsArray(value.profiles) then
        return nil, "Backup profiles must be an array."
    end

    local profiles = {}
    local profileNames = {}
    for index, sourceProfile in ipairs(value.profiles) do
        local profile
        profile, errorMessage = ValidateProfile(
            sourceProfile, "Backup profile " .. index
        )
        if not profile then return nil, errorMessage end
        if string.lower(profile.name) == string.lower(DEFAULT_PROFILE_NAME) then
            return nil, "The built-in Default profile cannot be imported from a backup."
        end

        local normalizedName = string.lower(profile.name)
        if profileNames[normalizedName] then
            return nil, "The backup contains more than one profile named " .. profile.name .. "."
        end
        profileNames[normalizedName] = true
        profiles[profile.name] = profile.categories
    end

    if type(value.activeProfiles) ~= "table"
        or JSON.IsArray(value.activeProfiles)
        or value.activeProfiles == JSON.Null then
        return nil, "Backup character assignments must be an object."
    end

    local activeProfiles = {}
    for characterKey, profileName in pairs(value.activeProfiles) do
        if type(characterKey) ~= "string"
            or characterKey == ""
            or #characterKey > MAX_CHARACTER_KEY_LENGTH then
            return nil, "Backup character assignments contain an invalid character name."
        end
        if type(profileName) ~= "string" then
            return nil, "The profile assigned to " .. characterKey .. " must be a string."
        end
        if profileName ~= DEFAULT_PROFILE_NAME and not profiles[profileName] then
            return nil, "Character " .. characterKey
                .. " is assigned to a profile that is not in the backup."
        end
        activeProfiles[characterKey] = profileName
    end

    return {
        type = "backup",
        settings = importedSettings,
        profiles = profiles,
        activeProfiles = activeProfiles,
        profileCount = #value.profiles
    }
end

function Serialization.ImportCategory(categoryIndex, text)
    if not Database.CanEditActiveProfile() then
        return false, "The Default profile cannot receive imports."
    end
    if not IsValidCategoryIndex(categoryIndex) then
        return false, "Choose a valid category to import."
    end

    local imported, errorMessage = Serialization.Decode(text, "category")
    if not imported then return false, errorMessage end
    Database.GetCategories()[categoryIndex] = imported.category
    if addon.Settings and addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors(categoryIndex)
    end
    if addon.MainWindow and addon.MainWindow.UpdateMenu then
        addon.MainWindow.UpdateMenu()
    end
    return true, imported.name
end

function Serialization.ImportProfile(text)
    if not Database.CanEditActiveProfile() then
        return false, "The Default profile cannot receive imports."
    end
    local imported, errorMessage = Serialization.Decode(text, "profile")
    if not imported then return false, errorMessage end

    Database.GetActiveProfile().categories = imported.categories
    if addon.Settings and addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors()
    end
    if addon.MainWindow and addon.MainWindow.SetSelectedCategory then
        addon.MainWindow.SetSelectedCategory(1)
    end
    if addon.MainWindow and addon.MainWindow.UpdateMenu then
        addon.MainWindow.UpdateMenu()
    end
    return true, imported.name
end

function Serialization.ImportProfileAsNew(profileName, text)
    local validName, errorMessage = Database.ValidateNewProfileName(profileName)
    if not validName then return false, errorMessage end

    local imported
    imported, errorMessage = Serialization.Decode(text, "profile")
    if not imported then return false, errorMessage end

    local success, createdName = Database.CreateProfile(validName, imported.categories)
    if not success then return false, createdName end
    return true, createdName, imported.name
end

function Serialization.ImportSettings(text)
    local imported, errorMessage = Serialization.Decode(text, "settings")
    if not imported then return false, errorMessage end
    ApplyImportedSettings(imported.settings)
    return true
end

function Serialization.ImportBackup(text)
    local imported, errorMessage = Serialization.Decode(text, "backup")
    if not imported then return false, errorMessage end
    Database.ReplaceCustomProfiles(imported.profiles, imported.activeProfiles)
    ApplyImportedSettings(imported.settings)
    return true, imported.profileCount
end
