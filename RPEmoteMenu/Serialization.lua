local _, addon = ...

local Serialization = {}
addon.Serialization = Serialization

local Database = addon.Database
local JSON = addon.JSON
local FORMAT_NAME = "RPEmoteMenu"
local FORMAT_VERSION = 2
local LEGACY_FORMAT_VERSION = 1
local MAX_DOCUMENT_BYTES = 4 * 1024 * 1024
local MAX_PROFILE_NAME_LENGTH = 64
local MAX_CATEGORY_NAME_LENGTH = 128
local MAX_LABEL_LENGTH = 128
local MAX_COMMAND_LENGTH = 4096
local MAX_FONT_NAME_LENGTH = 128

local CATEGORY_DOCUMENT_FIELDS = {
    format = true, version = true, type = true, name = true, emotes = true
}
local PROFILE_DOCUMENT_FIELDS = {
    format = true,
    version = true,
    type = true,
    name = true,
    settings = true,
    categories = true
}
local PROFILE_FIELDS = {name = true, settings = true, categories = true}
local LEGACY_PROFILE_FIELDS = {name = true, categories = true}
local PROFILES_DOCUMENT_FIELDS = {
    format = true, version = true, type = true, profiles = true
}
local LEGACY_BACKUP_FIELDS = {
    format = true,
    version = true,
    type = true,
    settings = true,
    profiles = true,
    activeProfiles = true
}
local CATEGORY_FIELDS = {name = true, emotes = true}
local EMOTE_FIELDS = {label = true, defaultCommand = true, targetedCommand = true}

local PROFILE_SETTINGS_FIELDS = {
    locked = true,
    hideSettingsGear = true,
    showAtLogin = true,
    rememberMinimized = true,
    point = true,
    relativePoint = true,
    x = true,
    y = true,
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
    inactiveOpacity = true
}
local LEGACY_SETTINGS_FIELDS = {}
for key in pairs(PROFILE_SETTINGS_FIELDS) do
    if key ~= "point" and key ~= "relativePoint" then
        LEGACY_SETTINGS_FIELDS[key] = true
    end
end

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
local VALID_ANCHOR_POINTS = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true
}

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
        value, {r = true, g = true, b = true}, description
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
        value, allowedFields or CATEGORY_FIELDS, description
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


local function ValidateProfileSettings(value, legacy)
    local fields = legacy and LEGACY_SETTINGS_FIELDS or PROFILE_SETTINGS_FIELDS
    local valid, errorMessage = ValidateObject(value, fields, "Profile settings")
    if not valid then
        return nil, errorMessage
    end

    local imported = {}
    for _, key in ipairs(BOOLEAN_SETTING_KEYS) do
        imported[key], errorMessage = ValidateBoolean(value[key], "Setting " .. key)
        if imported[key] == nil then return nil, errorMessage end
    end

    if not legacy then
        if not VALID_ANCHOR_POINTS[value.point] then
            return nil, "Setting point is not supported."
        end
        if not VALID_ANCHOR_POINTS[value.relativePoint] then
            return nil, "Setting relativePoint is not supported."
        end
        imported.point = value.point
        imported.relativePoint = value.relativePoint
    end

    local positionPresent = value.x ~= nil or value.y ~= nil
    if positionPresent and (value.x == nil or value.y == nil) then
        return nil, "Window position must contain both x and y."
    end
    if not legacy and not positionPresent then
        return nil, "Profile settings must contain a window position."
    end
    if positionPresent then
        imported.x, errorMessage = ValidateNumber(
            value.x, -100000, 100000, "Window position x", true
        )
        if imported.x == nil then return nil, errorMessage end
        imported.y, errorMessage = ValidateNumber(
            value.y, -100000, 100000, "Window position y", true
        )
        if imported.y == nil then return nil, errorMessage end
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
        if not imported[key] then return nil, errorMessage end
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
        if not imported[key] then return nil, errorMessage end
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

    local base = Database.CopySettings(Database.GetSettings())
    for key, settingValue in pairs(imported) do
        base[key] = settingValue
    end
    base.selectedCategory = addon.DefaultSettings.selectedCategory
    base.minimized = addon.DefaultSettings.minimized

    return Database.CopySettings(base)
end


local function ValidateProfile(value, description, allowedFields, settingsRequired)
    local valid, errorMessage = ValidateObject(value, allowedFields, description)
    if not valid then return nil, errorMessage end

    local profileName
    profileName, errorMessage = ValidateString(
        value.name, MAX_PROFILE_NAME_LENGTH, description .. " name"
    )
    if not profileName then return nil, errorMessage end
    if profileName == "" then
        return nil, description .. " name cannot be empty."
    end

    local categories
    categories, errorMessage = ValidateCategories(value.categories, description)
    if not categories then return nil, errorMessage end

    local profileSettings
    if value.settings ~= nil then
        profileSettings, errorMessage = ValidateProfileSettings(value.settings, false)
        if not profileSettings then return nil, errorMessage end
    elseif settingsRequired then
        return nil, description .. " settings are missing."
    end

    return {
        name = profileName,
        settings = profileSettings,
        categories = categories
    }
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


local function ExportProfileSettings(source)
    local exported = {}

    for _, key in ipairs(BOOLEAN_SETTING_KEYS) do
        exported[key] = source[key]
    end
    for _, key in ipairs({
        "point", "relativePoint", "x", "y", "width", "height", "sidebarWidth",
        "categoryFont", "emoteFont", "categoryFontSize", "emoteFontSize",
        "categoryHighlightEffect", "categoryHighlightThickness", "borderStyle",
        "backgroundOpacity", "windowOpacity", "fadeDelay", "inactiveOpacity"
    }) do
        exported[key] = source[key]
    end
    for _, key in ipairs(COLOR_SETTING_KEYS) do
        exported[key] = CopyColor(source[key])
    end

    return exported
end


local function ExportProfileData(profileName, profile)
    local categories = JSON.Array()
    for index = 1, addon.MAX_CATEGORIES do
        categories[index] = ExportCategoryData(profile.categories[index])
    end

    return {
        name = profileName,
        settings = ExportProfileSettings(profile.settings),
        categories = categories
    }
end


local function IsValidCategoryIndex(categoryIndex)
    return type(categoryIndex) == "number"
        and categoryIndex % 1 == 0
        and categoryIndex >= 1
        and categoryIndex <= addon.MAX_CATEGORIES
end


local function ValidateProfileArray(value, description, legacy, legacySettings)
    if not JSON.IsArray(value) then
        return nil, description .. " must be an array."
    end

    local profiles = {}
    local profileNames = {}
    local errorMessage
    for index, sourceProfile in ipairs(value) do
        local profile
        profile, errorMessage = ValidateProfile(
            sourceProfile,
            "Profile " .. index,
            legacy and LEGACY_PROFILE_FIELDS or PROFILE_FIELDS,
            not legacy
        )
        if not profile then return nil, errorMessage end

        local normalizedName = string.lower(profile.name)
        if profileNames[normalizedName] then
            return nil, "The import contains more than one profile named " .. profile.name .. "."
        end
        profileNames[normalizedName] = true

        if not profile.settings and legacySettings then
            profile.settings = Database.CopySettings(legacySettings)
        end
        profiles[#profiles + 1] = profile
    end

    return profiles
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
    local profileName = Database.GetActiveProfileName()
    local result = ExportProfileData(profileName, Database.GetProfile(profileName))
    result.format = FORMAT_NAME
    result.version = FORMAT_VERSION
    result.type = "profile"
    return JSON.Encode(result, true)
end


function Serialization.ExportAllProfiles()
    local profiles = JSON.Array()
    for index, profileName in ipairs(Database.GetProfileNames()) do
        profiles[index] = ExportProfileData(
            profileName,
            Database.GetProfile(profileName)
        )
    end

    return JSON.Encode({
        format = FORMAT_NAME,
        version = FORMAT_VERSION,
        type = "profiles",
        profiles = profiles
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
    if value.version ~= FORMAT_VERSION and value.version ~= LEGACY_FORMAT_VERSION then
        return nil, "This import format version is not supported."
    end

    local actualType = value.type == "backup" and "profiles" or value.type
    if actualType ~= "category" and actualType ~= "profile" and actualType ~= "profiles" then
        return nil, "The import data has an unsupported type."
    end
    if expectedType and actualType ~= expectedType then
        return nil, "This is " .. actualType .. " data, not " .. expectedType .. " data."
    end

    if actualType == "category" then
        local valid
        valid, errorMessage = ValidateObject(value, CATEGORY_DOCUMENT_FIELDS, "Import data")
        if not valid then return nil, errorMessage end

        local category
        category, errorMessage = ValidateCategory(value, "Category", CATEGORY_DOCUMENT_FIELDS)
        if not category then return nil, errorMessage end
        return {type = "category", name = category.name, category = category}
    end

    if actualType == "profile" then
        local profile
        profile, errorMessage = ValidateProfile(
            value,
            "Profile",
            PROFILE_DOCUMENT_FIELDS,
            value.version == FORMAT_VERSION
        )
        if not profile then return nil, errorMessage end
        profile.type = "profile"
        return profile
    end

    if value.type == "backup" then
        local valid
        valid, errorMessage = ValidateObject(value, LEGACY_BACKUP_FIELDS, "Import data")
        if not valid then return nil, errorMessage end
        if value.version ~= LEGACY_FORMAT_VERSION then
            return nil, "This legacy backup version is not supported."
        end

        local legacySettings
        legacySettings, errorMessage = ValidateProfileSettings(value.settings, true)
        if not legacySettings then return nil, errorMessage end

        local profiles
        profiles, errorMessage = ValidateProfileArray(
            value.profiles,
            "Backup profiles",
            true,
            legacySettings
        )
        if not profiles then return nil, errorMessage end
        return {type = "profiles", profiles = profiles, profileCount = #profiles}
    end

    local valid
    valid, errorMessage = ValidateObject(value, PROFILES_DOCUMENT_FIELDS, "Import data")
    if not valid then return nil, errorMessage end
    if value.version ~= FORMAT_VERSION then
        return nil, "This all-profiles export version is not supported."
    end

    local profiles
    profiles, errorMessage = ValidateProfileArray(
        value.profiles, "Profiles", false
    )
    if not profiles then return nil, errorMessage end
    return {type = "profiles", profiles = profiles, profileCount = #profiles}
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


function Serialization.ImportProfileAsNew(text)
    local imported, errorMessage = Serialization.Decode(text, "profile")
    if not imported then return false, errorMessage end

    local names = Database.AddImportedProfiles({imported})
    return true, names[1], imported.name
end


function Serialization.ImportAllProfiles(text)
    local imported, errorMessage = Serialization.Decode(text, "profiles")
    if not imported then return false, errorMessage end

    local names = Database.AddImportedProfiles(imported.profiles)
    return true, #names, names
end
